rm -fr ./build
npx antora antora-playbook.yml
touch build/site/.nojekyll

asciidoctor-epub3 -a epub3-stylesdir=epub -r asciidoctor-mathematical -D build/site/ru wtd.adoc
asciidoctor-pdf --theme pdf/wtd.yml -r asciidoctor-mathematical -D build/site/ru wtd.adoc
asciidoctor-pdf-optimize build/site/ru/wtd.pdf