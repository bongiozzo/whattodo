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

Инструменты вынесены в отдельный git модуль (submodule): `tooling/text-forge`.

### Подготовка

```bash
git submodule update --init --recursive
```

Зависимости:

- `uv` (управляет Python-зависимостями проекта из `pyproject.toml`)
- `pandoc` (внешняя утилита, ставится отдельно)

Дальше (один раз на машину / после обновления зависимостей):

```bash
uv sync
```

### Команды

```bash
make PYTHON='uv run python' MKDOCS='uv run mkdocs'          # EPUB + сайт (как в CI)
make PYTHON='uv run python' MKDOCS='uv run mkdocs' epub     # только EPUB
make PYTHON='uv run python' MKDOCS='uv run mkdocs' mkdocs   # собрать сайт (EPUB будет построен автоматически)
make PYTHON='uv run python' test                            # прогон проверок (expects build artifacts)
```

Если submodule не инициализирован, команды `make` не найдут скрипты сборки.

[![Built with Material for MkDocs](https://img.shields.io/badge/Material_for_MkDocs-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://squidfunk.github.io/mkdocs-material/)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bongiozzo/whattodo)
