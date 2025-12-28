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

Можно редактировать или удалить все главы, но важно сохранить `text/ru/index.md` и структуру папок (порядок глав задаётся в `mkdocs.yml`).
Стили сайта: `text/ru/assets/css/extra.css` (подключается через `mkdocs.yml` → `extra_css`).
Остальные файлы в `text/ru/assets/` можно удалять или оставить для примера.
Изображения лежат в `text/ru/img/` — можно удалить/заменить на свои и использовать в тексте.

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

- `git` (нужен для submodule)
- `uv` (Python tooling ставится внутри `text-forge/`)
- `pandoc` (внешняя утилита, ставится отдельно; нужен только для EPUB)

Дальше (один раз на машину / после обновления зависимостей):

```bash
make install
```

### Команды

```bash
make serve          # быстрый локальный предпросмотр (без EPUB и без pandoc)

make                # EPUB + сайт (как в CI)
make epub           # только EPUB
make site           # собрать сайт (EPUB будет построен автоматически)
```

Проверки (остаются в `text-forge`):

```bash
make -C text-forge CONTENT_ROOT=$PWD test
```

`make serve` не строит EPUB и не требует `pandoc`; он также отключает `git-committers` плагин через `MKDOCS_GIT_COMMITTERS_ENABLED=false`, чтобы упростить локальный вывод.
Если submodule не инициализирован, команды сборки не найдут tooling (`text-forge`).

[![Built with Material for MkDocs](https://img.shields.io/badge/Material_for_MkDocs-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://squidfunk.github.io/mkdocs-material/)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bongiozzo/whattodo)
