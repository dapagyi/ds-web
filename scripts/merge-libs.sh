#!/bin/bash
set -e

NOTEBOOKS_DIR="${1:-out/notebooks}"
SHARED_LIBS="$NOTEBOOKS_DIR/libs"

[ ! -d "$NOTEBOOKS_DIR" ] && echo "Error: $NOTEBOOKS_DIR not found" && exit 1

echo "Merging lib files..."

# Find first *_files directory that contains libs
SOURCE=""

while IFS= read -r dir; do
  if [ -d "$dir/libs" ]; then
    SOURCE="$dir"
    break
  fi
done < <(find "$NOTEBOOKS_DIR" -maxdepth 1 -type d -name "*_files" 2>/dev/null)

if [ -z "$SOURCE" ]; then
  echo "No *_files directories with libs found (nothing to merge)"
  exit 0
fi

# Create merged libs if missing
mkdir -p "$SHARED_LIBS"

# Copy libs from all *_files directories
find "$NOTEBOOKS_DIR" -maxdepth 1 -type d -name "*_files" 2>/dev/null | while read -r dir; do
  if [ -d "$dir/libs" ]; then
    echo "Copying libs from $dir"
    cp -rn "$dir/libs/"* "$SHARED_LIBS/" 2>/dev/null || true
  fi
done
echo "✓ Shared libs directory populated"

echo "Merging figures..."

FIGS_DIR="$NOTEBOOKS_DIR/figure-html"
mkdir -p "$FIGS_DIR"

# Move/copy figure-html directories into figure-html/<notebook>/ 
find "$NOTEBOOKS_DIR" -maxdepth 1 -type d -name "*_files" | while read -r dir; do
  NOTEBOOK=$(basename "$dir" _files)
  SRC="$dir/figure-html"

  # Only process if figure-html exists
  if [ -d "$SRC" ]; then
    DEST="$FIGS_DIR/$NOTEBOOK"
    mkdir -p "$DEST"

    echo "  → Copying figures for $NOTEBOOK"
    cp -rn "$SRC/"* "$DEST/" 2>/dev/null || true
  fi
done

echo "✓ Figures merged"

# Update HTML references only if needed
for html in "$NOTEBOOKS_DIR"/*.html; do
  [ ! -f "$html" ] && continue
  base=$(basename "$html" .html)
  # Only rewrite if pattern appears
  if grep -q "${base}_files/libs/" "$html"; then
    sed -i "s|${base}_files/libs/|libs/|g" "$html"
    echo "✓ Updated $(basename "$html")"

    # Update figure-html references
    # Replace: <notebook>_files/figure-html/  →  figure-html/<notebook>/
    if grep -q "${base}_files/figure-html/" "$html"; then
      sed -i "s|${base}_files/figure-html/|figure-html/${base}/|g" "$html"
      echo "✓ Updated figure paths in $(basename "$html")"
    fi
  fi
done

# Cleanup original *_files dirs
find "$NOTEBOOKS_DIR" -maxdepth 1 -type d -name "*_files" 2>/dev/null | while read -r dir; do
  if [ -d "$dir/libs" ]; then
    rm -rf "$dir/libs" || true
    echo "✓ Removed $dir/libs"
  fi
  
  # If empty, delete
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    rmdir "$dir" || true
    echo "✓ Removed empty $dir"
  fi

  # Remove figure-html dirs
  if [ -d "$dir/figure-html" ]; then
    rm -rf "$dir/figure-html"
    echo "✓ Removed $dir/figure-html"
  fi

  # Remove empty *_files dirs
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
    rmdir "$dir"
    echo "✓ Removed empty $dir"
  fi

done

echo "✓ Cleanup complete"
