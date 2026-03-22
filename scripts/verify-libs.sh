#!/bin/bash
set -e

# Script to verify that lib files with the same name are identical across notebooks

NOTEBOOKS_DIR="${1:-out/notebooks}"

if [ ! -d "$NOTEBOOKS_DIR" ]; then
  echo "Error: Directory $NOTEBOOKS_DIR does not exist"
  exit 1
fi

echo "Verifying lib files in $NOTEBOOKS_DIR"
echo "=========================================="

# Find all *_files directories
LIB_DIRS=$(find "$NOTEBOOKS_DIR" -maxdepth 1 -type d -name "*_files")

if [ -z "$LIB_DIRS" ]; then
  echo "No *_files directories found"
  exit 0
fi

# Create a temporary directory for comparison
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Collect all unique lib file paths (relative to *_files dirs)
declare -A FILE_PATHS

for lib_dir in $LIB_DIRS; do
  while IFS= read -r -d '' file; do
    # Get relative path from the *_files directory
    rel_path="${file#$lib_dir/}"
    FILE_PATHS["$rel_path"]=1
  done < <(find "$lib_dir/libs" -type f -print0 2>/dev/null || true)
done

# Now compare each unique file across all directories
MISMATCHES=0
TOTAL_FILES=0

for rel_path in "${!FILE_PATHS[@]}"; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  
  # Collect all instances of this file
  instances=()
  for lib_dir in $LIB_DIRS; do
    full_path="$lib_dir/$rel_path"
    if [ -f "$full_path" ]; then
      instances+=("$full_path")
    fi
  done
  
  # Skip if less than 2 instances
  if [ ${#instances[@]} -lt 2 ]; then
    continue
  fi
  
  # Compare all instances with the first one
  first_file="${instances[0]}"
  first_hash=$(md5sum "$first_file" | cut -d' ' -f1)
  
  all_match=true
  for ((i=1; i<${#instances[@]}; i++)); do
    current_file="${instances[$i]}"
    current_hash=$(md5sum "$current_file" | cut -d' ' -f1)
    
    if [ "$first_hash" != "$current_hash" ]; then
      all_match=false
      if [ $MISMATCHES -eq 0 ]; then
        echo ""
        echo "MISMATCHES FOUND:"
        echo "================="
      fi
      MISMATCHES=$((MISMATCHES + 1))
      echo ""
      echo "File: $rel_path"
      echo "  $first_file (md5: $first_hash)"
      echo "  $current_file (md5: $current_hash)"
    fi
  done
  
  if $all_match; then
    echo "✓ $rel_path (${#instances[@]} identical instances)"
  fi
done

echo ""
echo "=========================================="
echo "Total unique files checked: $TOTAL_FILES"
echo "Mismatches found: $MISMATCHES"

if [ $MISMATCHES -gt 0 ]; then
  echo ""
  echo "ERROR: Some lib files differ across notebooks!"
  exit 1
else
  echo ""
  echo "SUCCESS: All lib files are identical!"
  exit 0
fi