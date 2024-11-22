export CI=true

rm -fr ./build
npx antora antora-playbook.yml
touch build/site/.nojekyll

asciidoctor-epub3 -a epub3-stylesdir=epub -D build/site/ru wtd.adoc
asciidoctor-pdf --theme pdf/wtd.yml -D build/site/ru wtd.adoc
asciidoctor-pdf-optimize build/site/ru/wtd.pdf