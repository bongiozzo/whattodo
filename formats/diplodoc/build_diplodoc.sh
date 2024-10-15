# Execute DiploDoc Builder to HTML
SOURCE_PATH="docs"
SOURCE_PATH_LANG="docs/ru"
SOURCE_IMAGES="docs/_images"
DD_PATH="diplodoc"
DD_PATH_LANG="diplodoc/ru"
DD_PATH_IMAGES="diplodoc/_images"
OUTPUT_PATH="docs-html"

# Copy md files
rm $DD_PATH_LANG/*.md
cp $SOUCE_PATH_LANG/*.md $DD_PATH_LANG

# Copy image files
for file in "$SOURCE_IMAGES"/*; do
    filename=$(basename "$file")
    extension=${filename##*.}
    if [ ! -f "$DD_PATH_IMAGES/$filename" ]; then
        cp "$file" "$DD_PATH_IMAGES/"
        if [extension -eq "jpg" || extension -eq "png" ]; then
            mogrify -resize '1024x1024>' $DD_PATH_IMAGES/$filename
        fi
        echo "$filename was copied and resized"
    fi
done

# Massive replacements
sed -i -E -f dd_replacement.sed $DD_PATH_LANG/*.md

rm -fr ./$OUTPUT_PATH
npx -- @diplodoc/cli@latest -i $DD_PATH -o $OUTPUT_PATH --single-page --allow-custom-resources

# Build PDF

npx -- @diplodoc/pdf-generator@latest -i $OUTPUT_PATH 
mv $OUTPUT_PATH/ru/single-page.pdf $OUTPUT_PATH/wtd.pdf

# Build pandoc Epub and FB2

EPUB_PATH="epub"
EPUB_PATH_LANG="epub/ru"
EPUB_PATH_IMAGES="epub/_images"

pandoc -o $OUTPUT_PATH/wtd.epub --epub-cover-image=$EPUB_PATH_IMAGES/forward.jpg --resource-path=$EPUB_PATH_LANG `ls $EPUB_PATH_LANG/*.md`

# YFM style INFO Formulas? Register

# Dark theme