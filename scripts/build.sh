# docker run -u $(id -u) -v $PWD:/antora:Z --rm -t whattodo:latest antora-playbook.yml
export CI=true

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

BOOKADOC="ru/modules/ROOT/book.adoc"
rm -fr ./public
npx antora --fetch antora-playbook.yml

# Generate books
# Change accordingly of Site Structure - here 2 levels with parts
sed -E 's/\*\* (xref:([^[]+)\[\])/include::pages\/\2[leveloffset=+1]\n/g; s/\* (.+)/= \1\n/g; 1s/^/\/\/ GENERATED - edit nav.adoc\n\n/' ru/modules/ROOT/nav.adoc > ru/modules/ROOT/generated-toc.adoc

# Strange behavior of styledir for epub converter
asciidoctor-epub3 -a epub3-stylesdir=../../../epub -D public/ru $BOOKADOC
asciidoctor-pdf --theme pdf/pdf.yml -D public/ru $BOOKADOC
asciidoctor-pdf-optimize public/ru/book.pdf
asciidoctor-reducer -o public/ru/book.txt $BOOKADOC 
