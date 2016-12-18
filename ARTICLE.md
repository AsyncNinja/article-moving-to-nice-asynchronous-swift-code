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

extension MyViewController {
  func present(personWithID identifier: String) {
    DispatchQueue.global().async { // do not forget to dispatch to background
      do {
        let person = try self.myService.person(identifier: identifier)
        DispatchQueue.main.async { // do not forget ot dispatch to main
          self.present(person: person)
        }
      } catch {
        DispatchQueue.main.async { // do not forget ot dispatch to main
          self.present(error: error)
        }
      }
    }
  }
}
```

Pretty straightforward. `input arguments -> output result`. Both methods can either return person *(or nil if there is no such person)* or throw issue if something went wrong.

**Pros**

* looks super simple

**Cons**

* hides great danger

## Revealing great danger
Comment describes the only issue there is. Don't call after on main thread. This caveat is close to *never feed it after midnight*.

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

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) { (person, error) in
      DispatchQueue.main.async { // do not forget ot dispatch to main
        if let error = error {
          self.present(error: error)
        } else {
          self.present(person: person)
        }
      }
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

extension MyViewController {
  func present(personWithID identifier: String) {
    // let _ = ... looks ugly because AsyncNinja does not provide onCompletion(executor:...) on purpose (see 2.2)
    let _ = self.myService.person(identifier: identifier)
      .mapCompletion(executor: .main) { // remember to dispatch to main
        (personOrError) -> Void in
        switch personOrError {
        case .success(let person):
          self.present(person: person)
        case .failure(let error):
          self.present(error: error)
        }
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

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) {
      [weak self] (person, error) in //do not forget weak self
      DispatchQueue.main.async {
        [weak self] in // do not forget ot dispatch to main, do not forget weak self
        guard let strongSelf = self else { return }
        if let error = error {
          strongSelf.present(error: error)
        } else {
          strongSelf.present(person: person)
        }
      }
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
* uglier than 1.0
* too much complexity to remember

## Bugfix 2.1 - Futures (full story)
```swift
extension MyService {
  public func person(identifier: String) throws -> Person? {
    return /*fetch Person from network*/
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onCompletion(executor: .main) { // remember to dispatch to main
        [weak self] (personOrError) in // remember weak self
        guard let strongSelf = self else { return }
        switch personOrError {
        case .success(let person):
          strongSelf.present(person: person)
        case .failure(let error):
          strongSelf.present(error: error)
        }
    }
  }
}
```

**Pros**

* removes great danger
* removes lesser danger

**Cons**

* uglier than 2.0
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

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onComplete(context: self) { (self, personOrError) in
        switch personOrError {
        case .success(let person):
          self.present(person: person)
        case .failure(let error):
          self.present(error: error)
        }
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