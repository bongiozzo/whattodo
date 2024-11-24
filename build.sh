export CI=true

rm -fr ./public
npx antora antora-playbook.yml

asciidoctor-epub3 -a epub3-stylesdir=epub -D public/ru wtd.adoc
asciidoctor-pdf --theme pdf/wtd.yml -D public/ru wtd.adoc
asciidoctor-pdf-optimize public/ru/wtd.pdf