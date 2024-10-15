# Execute DiploDoc Builder to HTML
DD_PATH="docs"
DD_PATH_LANG="docs/ru"
DD_PATH_IMAGES="docs/_images"
SOURCE_IMAGES=".gitbook/assets"
OUTPUT_PATH="docs-html"

# Copy image files
for file in "$SOURCE_IMAGES"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        if [ ! -f "$DD_PATH_IMAGES/$filename" ]; then
            cp "$file" "$DD_PATH_IMAGES/"
            mogrify -resize '1024x1024>' $DD_PATH_IMAGES/$filename
            echo "$filename was copied and resized"
        fi
    fi
done

rm -fr $OUTPUT_PATH
npx -- @diplodoc/cli@next -i $DD_PATH -o $OUTPUT_PATH --single-page --allow-custom-resources

# Build PDF 

npx -- @diplodoc/pdf-generator@latest -i $OUTPUT_PATH 
mv $OUTPUT_PATH/ru/single-page.pdf $OUTPUT_PATH/wtd.pdf

# Build pandoc Epub and FB2

# pandoc -o $OUTPUT_PATH/wtd.epub --resource-path=$DD_PATH_LANG `ls $DD_PATH_LANG/*.md`

# YFM style INFO Formulas? Register

# Dark theme