pandoc combined.md -o book.epub \
  --toc \
  --toc-depth=3 \
  --epub-chapter-level=1 \
  --css=epub-style.css \
  --metadata title="Что мне делать? :-)" \
  --metadata author="Сергей Поляков" \
  --metadata lang=ru