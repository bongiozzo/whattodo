FROM debian:latest

WORKDIR /antora

RUN apt-get update && apt-get install -y nodejs npm ruby ruby-dev ghostscript && gem install asciidoctor-pdf asciidoctor-epub3 asciidoctor-reducer asciidoctor-revealjs rghost && npm i -g antora @antora/lunr-extension