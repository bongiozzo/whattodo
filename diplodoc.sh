# Execute DiploDoc Builder to HTML
dd_path="docs"
dd_path_lang="docs/ru"
dd_path_images="docs/_images"
output_path="docs-html"

rm -fr $output_path
npx -- @diplodoc/cli@latest -i $dd_path -o $output_path --single-page

# Build PDF 

npx -- @diplodoc/pdf-generator@latest -i $output_path

# Build pandoc Epub and FB2

pandoc -o $output_path/wtd.epub --resource-path=$dd_path_lang `ls $dd_path_lang/*.md`

# YFM style INFO Formulas? Register

# Dark theme