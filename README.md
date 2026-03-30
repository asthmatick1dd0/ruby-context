# ruby-context

![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-CC342D?logo=ruby&logoColor=white)
![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)
![License](https://img.shields.io/badge/License-GPL--3.0-blue)

Go-like `Context` для Ruby: минимальная реализация контекстов с отменой и propagation.

## Что уже есть

| Возможность | Статус | Примечание |
| --- | --- | --- |
| `Context.background` | Ready | Singleton, неотменяемый immutable-контекст |
| `Context.with_cancel(parent)` | Ready | Возвращает `[ctx, cancel_proc]` |
| Propagation отмены | Ready | Отмена родителя отменяет детей |
| Ошибки контекста | Ready | `:canceled`, `:deadline_exceeded` |

## Быстрый старт

### Установка зависимостей

```bash
bundle install
```

### Линтер

```bash
bundle exec rubocop
```

### Тесты

```bash
bundle exec rspec ./spec/
```

## Пример использования

```ruby
require 'context'

root = Context.background
ctx, cancel = Context.with_cancel(root)

puts ctx.done? # false
puts ctx.err   # nil

cancel.call

puts ctx.done? # true
puts ctx.err   # :canceled
```

## Структура проекта

```text
lib/
  context.rb
  context/
    errors.rb
spec/
  context_spec.rb
  spec_helper.rb
.github/workflows/
  ci.yml
Gemfile
ruby-context.gemspec
README.md
LICENSE
```


## Лицензия

Проект распространяется под лицензией **GNU GPL-3.0**. Подробности в файле [LICENSE](LICENSE).
