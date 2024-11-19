rm -fr ./build

cp source/* formats/antora/modules/ROOT/pages/
npx antora antora-playbook.yml
rm formats/antora/modules/ROOT/pages/*
touch build/site/.nojekyll

asciidoctor-epub3 -a epub3-stylesdir=formats/epub -r asciidoctor-mathematical -D build/site wtd.adoc
asciidoctor-pdf --theme formats/pdf/wtd.yml -r asciidoctor-mathematical -D build/site wtd.adoc
asciidoctor-pdf-optimize build/site/wtd.pdf