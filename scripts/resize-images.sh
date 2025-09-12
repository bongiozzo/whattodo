#!/bin/bash

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

images_dir="ru/modules/ROOT/images"

images=$(find "$images_dir" -type f \( -iname "*.jpg" -o -iname "*.png" \))
for img in $images; do
  # Get image width and height
  read width height < <(magick identify -format "%w %h" "$img")
  
  # Check if width or height is greater than 100
  if [ "$width" -gt 1920 ] || [ "$height" -gt 1080 ]; then
    magick mogrify -resize '1920x1080>' "$img"
    echo "Resized $img from ${width}x${height}"
  fi
done
find "$images_dir" -type f \( -iname "*.jpg" -o -iname  "*.png" \) -exec identify -format "%B %f: %wx%h\n" {} + | sort -h
