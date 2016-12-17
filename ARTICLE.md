# Steps towards asynchronous code

## Before we start
Let's describe what we want. `Person`, `MyService`.

## Life Before Asynchronous Code

```swift
extension MyService {
  func person(identifier: String) throws -> Person? {
    return /*fetch Person from network*/
  }
}
```

Pretty straightforward. `input arguments -> output result`. Both methods can either return person *(or nil if there is no such person)* or throw issue if something went wrong.

**Pros**

* looks super simple

**Cons**

* hides great danger

## Revealing great danger
Comment describes the only issue there is. Don't call after on main thread. This caviat is close to *never feed it after midnight*.

## Release 1.0 - Async with callbacks
```swift
extension MyService {
  public func person(identifier: String,
                     callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async {
      let person = /*fetch Person from network*/
      callback(person, nil) // I really hope you will not forget to add call of callback here
    }
  }
}
```

**Pros**

* removes great danger

**Cons**

* easy to forget to call callback at the end
* method output is listed as argument
* *still hides danger, see [Bugfix-1.1]*

## Release 2.0 - Futures
```swift
extension MyService {
  public func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) { _ in
      return /*fetch Person from network*/
    }
  }
}
```

**Pros**

* removes great danger
* not ugly any more

**Cons**

* one more library
* *still hides danger, see [Bugfix-1.1, Bugfix-2.1]*

## Revealing lesser danger
Consideration of `MyService` lifetime

## Bugfix 1.1 - Async with callbacks (full story)
```swift
extension MyService {
  public func person(identifier: String,
                     callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async { [weak self] in
      guard let strongSelf = self else {
        callback(nil, ModelError.serviceIsMissing)
        return
      }

      let person = /*fetch Person from network*/
      callback(person, nil)
    }
  }
}

```

**Pros**

* removes great danger
* removes lesser danger

**Cons**

* easy to forget to call callback at the end
* method output is listed as argument
* uglier then 1.0
* too much complexity to remember

## Bugfix 2.1 - Futures (full story)
```swift
extension MyService {
  public func person(identifier: String) throws -> Person? {
    return /*fetch Person from network*/
  }
}
```

**Pros**

* removes great danger
* removes lesser danger

**Cons**

* uglier then 2.0
* too much complexity to remember
* one more library

## Refactoring 2.2 - Futures and ExecutionContext
```swift
extension MyService {
  public func person(identifier: String) -> Future<Person?> {
    return future(context: self) { (self) in
      return /*fetch Person from network*/
    }
  }
}
```

**Pros**

* removes great danger
* removes lesser danger
* almost as beautiful as sync implementation

**Cons**

* one more library

## Summary