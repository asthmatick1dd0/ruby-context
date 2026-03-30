# Ruby Context API Documentation

## Обзор

Ruby Context - это Go-подобная реализация контекстов для Ruby с поддержкой отмены, propagation и thread-safety.

---

## API Reference

### `Context.background`

Создает singleton background контекст, который никогда не завершается.

**Возвращает:** `Context`

**Пример:**
```ruby
ctx = Context.background
ctx.done?  # => false
ctx.err    # => nil
```

---

### `Context.with_cancel(parent)`

Создает отменяемый контекст с указанным родителем.

**Параметры:**
- `parent` (Context) - родительский контекст

**Возвращает:** `Array[Context, Proc]` - массив из контекста и callable для отмены

**Пример:**
```ruby
ctx, cancel = Context.with_cancel(Context.background)
ctx.done?  # => false

cancel.call
ctx.done?  # => true
ctx.err    # => :canceled
```

---

### `#done?`

Проверяет, завершен ли контекст.

**Возвращает:** `Boolean`

**Возвращает `true` если:**
- Контекст отменен через `cancel!`
- Родительский контекст отменен (propagation)
- Deadline истек (в будущих версиях)

**Возвращает `false` если:**
- Контекст активен
- Контекст - это `background` (background никогда не завершается)

**Пример:**
```ruby
ctx, cancel = Context.with_cancel(Context.background)
ctx.done?  # => false

cancel.call
ctx.done?  # => true
```

---

### `#cancel!`

Отменяет контекст и рекурсивно все дочерние контексты.

**Возвращает:** `nil`

**Поведение:**
- Устанавливает `@canceled = true`
- Устанавливает ошибку `CanceledError`
- Рекурсивно отменяет всех детей
- Для `background` игнорируется (не выполняет действий)
- **Thread-safe** (использует `Mutex`)

**Пример:**
```ruby
parent, _ = Context.with_cancel(Context.background)
child, _ = Context.with_cancel(parent)

parent.cancel!

parent.done?  # => true
child.done?   # => true (propagation)
```

---

### `#err`

Возвращает ошибку контекста или `nil` если контекст активен.

**Возвращает:** `Symbol` или `nil`

**Возможные значения:**
- `:canceled` - контекст или родитель отменен
- `:deadline_exceeded` - deadline истек (в будущих версиях)
- `nil` - контекст активен

**Пример:**
```ruby
ctx, cancel = Context.with_cancel(Context.background)
ctx.err  # => nil

cancel.call
ctx.err  # => :canceled
```

---

## Примеры использования

### Базовая отмена

```ruby
require 'context'

ctx, cancel = Context.with_cancel(Context.background)
puts ctx.done?  # => false

cancel.call
puts ctx.done?  # => true
puts ctx.err    # => :canceled
```

### Propagation (каскадная отмена)

```ruby
parent, parent_cancel = Context.with_cancel(Context.background)
child1, _ = Context.with_cancel(parent)
child2, _ = Context.with_cancel(parent)

# Отменяем родителя
parent_cancel.call

# Все дети автоматически отменены
puts child1.done?  # => true
puts child2.done?  # => true
puts child1.err    # => :canceled
```

### Вложенные контексты

```ruby
level1, cancel1 = Context.with_cancel(Context.background)
level2, cancel2 = Context.with_cancel(level1)
level3, cancel3 = Context.with_cancel(level2)

cancel1.call  # Отменяем уровень 1

# Все дочерние уровни отменены
puts level1.done?  # => true
puts level2.done?  # => true
puts level3.done?  # => true
```

### Прямой вызов cancel!

```ruby
ctx, _ = Context.with_cancel(Context.background)
ctx.cancel!  # Можно вызвать напрямую

puts ctx.done?  # => true
```

---

## Thread Safety

Все операции с контекстом являются **thread-safe**:
- `#done?` - использует `Mutex`
- `#cancel!` - использует `Mutex`
- `#err` - использует `Mutex`
- Регистрация детей - использует `Mutex`

---

## Особенности

### Background Context
- Singleton (всегда один и тот же объект)
- Никогда не завершается (`done?` всегда `false`)
- Нельзя отменить (`cancel!` игнорируется)
- Используется как корневой контекст

### Propagation
- Отмена родителя автоматически отменяет всех детей
- Работает рекурсивно на любую глубину
- Родитель не изменяется при создании детей (immutable)

### Immutability
- Родительский контекст не мутирует при создании дочерних
- Дети регистрируются во внутреннем списке `@children`
- Родитель остается неизменным снаружи
