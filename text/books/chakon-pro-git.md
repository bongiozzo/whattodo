---
title: Pro Git
author: Скотт Чакон, Бен Штрауб
tags:
  - book
status: read
my_mark: 5
livelib_book: "https://www.livelib.ru/book/1001502890"
livelib_review: "https://www.livelib.ru/review/5457061-pro-git-skott-chakon"
---

## Рецензия

Книга доступна в открытом исходнике, что полностью соответствует концепции Open Source.

Процесс сборки и электронной публикации книги полностью автоматизирован.

Читал в оригинале, на английском, чтобы не потерять специфики.

Разработчикам, пожалуй, отдельно не стоит писать рецензию, зачем нужно изучать Git.



Скажу пару слов  для тех, кто далёк от программирования.

Хранение и переиспользование текстовой информации в концепции Git очень напоминает ДНК.

Нет единственно «правильной» версии, как в широко известном Вики формате представления информации.

В концепции Git у каждого участника есть своя версия текста, но они связаны между собой и наследуются друг от друга.

Всегда можно посмотреть сколько общих частей в текстах разных инстанций.

Чем они отличаются и в какой момент времени эти различия появились.

Как устроена такая система внутри, на мой взгляд, может быть любопытно даже далеким от разработки людям.

И эта книга на простых примерах с картинками объясняет все нюансы.

Начиная с краткой истории эволюционного появления Git.

> Do not rebase commits that exist outside your repository and that people may have based work on.
>
>
>
> If you follow that guideline, you’ll be fine.
>
> If you don’t, people will hate you, and you’ll be scorned by friends and family. ^quote_1

livelib: https://www.livelib.ru/quote/48505159

> One point of view on this is that your repository’s commit history is a record of what actually happened.
>
> It’s a historical document, valuable in its own right, and shouldn’t be tampered with.
>
>
>
> From this angle, changing the commit history is almost blasphemous; you’re lying about what actually transpired.
>
>
>
> So what if there was a messy series of merge commits?
>
>
>
> That’s how it happened, and the repository should preserve that for posterity.
>
>
>
> The opposing point of view is that the commit history is the story of how your project was made.
>
> You wouldn’t publish the first draft of a book, so why show your messy work?
>
>
>
> When you’re working on a project, you may need a record of all your missteps and dead-end paths, but when it’s time to show your work to the world, you may want to tell a more coherent story of how to get from A to B. ^quote_2

livelib: https://www.livelib.ru/quote/48505165
