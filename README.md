# Что мне делать? :-)

[Текст](https://text.sharedgoals.ru/) в [концепции Open Source](https://text.sharedgoals.ru/ru/p2-170-opensource), основной целью которого является планирование деятельности, приносящей радость и [моменты счастья](https://text.sharedgoals.ru/ru/p1-010-happiness#moments_of_happiness).

## Инструкция по созданию собственного Текста

<https://text.sharedgoals.ru/ru/p2-200-text#text_instruction>

## Локальная сборка (для проверки перед публикацией)

В репозитории используется git submodule с инструментами сборки: `tooling/text-forge`.

### Подготовка

```bash
git clone https://github.com/bongiozzo/whattodo.git
cd whattodo
git submodule update --init --recursive
```

Зависимости:

- `python3` (рекомендуется 3.11+)
- `mkdocs`
- `pandoc`

### Команды

```bash
make          # EPUB + сайт (как в CI)
make epub     # только EPUB
make mkdocs   # собрать сайт (EPUB будет построен автоматически)
make test     # прогон проверок (expects build artifacts)
```

Если submodule не инициализирован, команды `make` не найдут скрипты сборки.

[![Built with Material for MkDocs](https://img.shields.io/badge/Material_for_MkDocs-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://squidfunk.github.io/mkdocs-material/)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bongiozzo/whattodo)
