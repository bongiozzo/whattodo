# Что мне делать? :-)

[Текст](https://text.sharedgoals.ru/) в [концепции Open Source](https://text.sharedgoals.ru/ru/p2-170-opensource), основной целью которого является планирование деятельности, приносящей радость и [моменты счастья](https://text.sharedgoals.ru/ru/p1-010-happiness#moments_of_happiness).

## Инструкция по созданию собственного Текста

<https://text.sharedgoals.ru/ru/p2-200-text#text_instruction>

## Публикация (самый простой способ)

Чтобы создать репозиторий с Вашим Текстом на GitHub Pages, достаточно взять в качестве примера имеющийся:

```bash
git clone https://github.com/bongiozzo/whattodo.git
cd whattodo
```

1) Отредактировать файлы в `text/ru/`.
2) Запустить команду git commit.
3) И следом – git push.

```bash
git commit -a -m "Мой Текст: первые правки"
git push
```

После `push` GitHub Actions сам соберёт сайт и EPUB.

### Через VS Code

Откройте вкладку **Source Control** → выберите файлы → напишите сообщение → **Commit** → **Sync/Push**.

## Локальная сборка (для проверки перед публикацией)

Локальная сборка нужна, если хотите проверить сайт/EPUB перед публикацией.
Это требует чуть больше настроек, чем публикация.

Инструменты вынесены в отдельный git модуль (submodule): `text-forge`.

### Подготовка

```bash
git submodule update --init --recursive
```

Зависимости:

- `uv` (управляет Python-зависимостями проекта из `pyproject.toml`)
- `mkdocs` (устанавливается как Python-зависимость проекта; нужен для сайта/serve)
- `pandoc` (внешняя утилита, ставится отдельно; нужен только для EPUB)

Дальше (один раз на машину / после обновления зависимостей):

```bash
uv sync
```

### Команды

```bash
make MKDOCS='uv run mkdocs' serve                           # быстрый локальный предпросмотр (без EPUB и без pandoc)

make PYTHON='uv run python' MKDOCS='uv run mkdocs'          # EPUB + сайт (как в CI)
make PYTHON='uv run python' MKDOCS='uv run mkdocs' epub     # только EPUB
make PYTHON='uv run python' MKDOCS='uv run mkdocs' site     # собрать сайт (EPUB будет построен автоматически)
make PYTHON='uv run python' test                            # прогон проверок (expects build artifacts)
```

`make serve` не использует `text-forge` и не требует `pandoc`; он отключает `git-committers` плагин через `MKDOCS_GIT_COMMITTERS_ENABLED=false`, чтобы упростить локальный вывод.
Если submodule не инициализирован, команды сборки (`make`, `make epub`, `make site`) не найдут скрипты.

[![Built with Material for MkDocs](https://img.shields.io/badge/Material_for_MkDocs-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://squidfunk.github.io/mkdocs-material/)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bongiozzo/whattodo)
