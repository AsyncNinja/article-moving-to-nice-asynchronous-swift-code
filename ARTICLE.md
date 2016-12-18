# Steps towards asynchronous code
This article is made to raise awareness about problems related to asynchronous code
and to provide examples solving such problems. *It also mildly advertises [AsyncNinja](http://async.ninja/) library.*

### Contents
* [Before we start](#before-we-start)
* [Life Before Asynchronous Code](#life-before-asynchronous-code)
* [Discussion of *"do not forget"*s](#discussion-of-do-not-forgets)
* [Attempt 1.0 - Async with callbacks](#attempt-10---async-with-callbacks)
* [Attempt 2.0 - Futures](#attempt-20---futures)
* [Revealing Danger](#bugfix-11---async-with-callbacks-full-story)
* [Bugfix 1.1 - Async with callbacks (full story)](#revealing-danger)
* [Bugfix 2.1 - Futures (full story)](#bugfix-21---futures-full-story)
* [Refactoring 2.2 - Futures and ExecutionContext](#refactoring-22---futures-and-executioncontext)
* [Summary](#summary)

### Let's describe example of problem.

* `Person` is an example of a struct that contains information about person.
* `MyService` is an example of a class that serves as an entry point to model.
* `MyViewController` is an example of a class that manages UI-related instances.

We want `MyService` to provide `Person` by identifier to `MyViewController`.
`MyService` may not have this information in memory, so fetching person might involve networking, disk operations and etc.

## Life Before Asynchronous Code
Let's face synchronous variant first. I notice that oh too many projects are still using this approach.

```swift
extension MyService {
  func person(identifier: String) throws -> Person? {
    return /*fetch Person from network*/
  }
}
```
Pretty straightforward. `input arguments -> output result`. Both methods can either
return person *(or nil if there is no such person)* or throw issue if something went wrong.
Let's take a look at usage.

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    DispatchQueue.global().async { // do not forget to dispatch to background
      do {
        let person = try self.myService.person(identifier: identifier)
        DispatchQueue.main.async { // do not forget to dispatch to main
          self.present(person: person)
        }
      } catch {
        DispatchQueue.main.async { // do not forget to dispatch to main
          self.present(error: error)
        }
      }
    }
  }
}
```
Not as beautiful as interface. [Cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity) is high too.

**Pros**

* `MyService` interface and implementation looks simple

**Cons**

* possibility of deadlocks in `MyService`
* "do not forget" **x3**
* *hides danger, see [Bugfix-1.1]*

## Discussion of *"do not forget"*s
*IMHO* each of *"do not forget"*s signalises about poor architecture.  Even if you are
some kind of robot that avoids mistakes in 99% of cases, application with 100
of such calls will have at least one critical issue.

In more realistic conditions such calls are often nested or parallelized
that adds triples amount of code, complexity, and chances to make mistake.
And we did not even think of possible deadlocks in `MyService` yet!

So let's try to fix these issues.

###Goal:
* fix "do not forgets"s
* avoid possibility of deadlocks
* provide reliable way of gluing ui and model together.

## Attempt 1.0 - Async with callbacks
Since OS X 10.6 and iOS 4.0 we had closures (aka blocks).
Using closures as callback opens another dimension in making asynchronous flows.

```swift
extension MyService {
   func person(identifier: String,
               callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async {
      let person = /*fetch Person from network*/
      callback(person, nil) // do not forget to add call of callback here
    }
  }
}
```
So we are passing callback as last argument. This actually interface a little bit uglier.
It looked pure*ish*, but now it is not. Let's see how we will use this interface.

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) { (person, error) in
      DispatchQueue.main.async { // do not forget to dispatch to main
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
[Cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity) has rised even higher.

*For those who see urge to add `weaks` all over the place. Go to [Bugfix 1.1 - Async with callbacks (full story)](#revealing-danger)*

**Pros**

* fixes 2 "do not forget"s
* possibility of deadlocks eliminated

**Cons**

* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x2**
* *hides danger, see [Bugfix-1.1]*

## Attempt 2.0 - Futures
```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) { _ in
      return /*fetch Person from network*/
    }
  }
}
```
This interface is almost as good as synchronous version. 


```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onCompletion(executor: .main) { // do not forget to dispatch to main
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

* `MyService` interface and implementation looks simple
* fixes 2 "do not forget"s
* possibility of deadlocks eliminated

**Cons**

* one more library
* "do not forget" **x2**
* *hides danger, see [Bugfix-1.1, Bugfix-2.1]*

## Revealing Danger
Let's talk about lifetime of `MyService` and `MyViewController`. Both of them are *active objects* that
are aware about queues, dispatches, threads and etc.
So here is scenario:

1. User taps button "Refresh Person Info"
2. `MyViewController` calls method `self.myService.person(identifier: identifier)`
3. `MyService` starts to fetch person from network
4. There are some network issues
5. User does want not wait for too long, so he is just closing window/popover/modal view/anything
6. Owner of `MyViewController` does not need the view controller any more. So owner releases reference to view controller assuming that all memory allocated by `MyViewController` will be released
7. `MyViewController` is still retained by closure, so it will retain it's resources until the request completes
8. Request might not complete for a while (depending on networking configs and etc)

As result: memory consumption will grow, operations will continue running if results are not required any more.
We have to fix this because memory and cpu resources are limited.

## Bugfix 1.1 - Async with callbacks (full story)
Usual fix is involves adding `weak`s all over the place.

```swift
extension MyService {
  func person(identifier: String,
              callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async { [weak self] in
      guard let strongSelf = self else {
        callback(nil, ModelError.serviceIsMissing) // do not forget to add call of callback here
        return
      }

      let person = /*fetch Person from network*/
      callback(person, nil) // do not forget to add call of callback here
    }
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) {
      [weak self] (person, error) in // do not forget weak self
      DispatchQueue.main.async { // do not forget to dispatch to main
        [weak self] in // do not forget weak self
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
This solution definitely fixes described issue but does not meet out [goals](#goals).

**Pros**

* removes hidden danger
* possibility of deadlocks eliminated

**Cons**

* looks ugly
* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x5**

## Bugfix 2.1 - Futures (full story)
Let's apply solution to futures-based approach. Maybe it will look better here.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) {
      [weak self] _ in // do not forget weak self
      guard let strongSelf = self
        else { throw ModelError.serviceIsMissing }
      return /*fetch person*/
    }
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onCompletion(executor: .main) { // do not forget to dispatch to main
        [weak self] (personOrError) in // do not forget weak self
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

Nope. It does not look better.

**Pros**

* removes hidden danger
* possibility of deadlocks eliminated

**Cons**

* one more library
* adds another kind of "do not forget"
* "do not forget" **x3**

Unfortunately, all libraries I've seen that provide futures for Swift finish here.
I had [goals](#goals) to achieve, so I had to move forward.

## Refactoring 2.2 - Futures and ExecutionContext
Let's make a few assumptions before we explore this solution.

1. for `MyService`
	* `MyService` is an active object that has mutable state
	* This state is allowed to change only on serial queue owned by `MyService`
	* `MyService` owns all operations it initiates, but neither of initiated operations own `MyService`
	* `MyService` communicates with another active objects predominantly using asynchronous calls only
2. for `MyViewController`
	* `MyViewController` is an active object that has mutable state (UI)
	* This state is allowed to change only on main queue
	* `MyViewController` owns all operations it initiates, but neither of initiated operations own `MyViewController`
	* `MyViewController` communicates with another UI related classes predominantly on main queue 
	* `MyViewController` communicates with another active objects predominantly using asynchronous calls

So I conclude that `MyService` and `MyViewController` can be conformed to
protocol `ExecutionContext` from [AsyncNinja](http://async.ninja/) library.
That basically means that they can asynchronously execute code that influences their lifetime and internal state.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
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

As you see, 99% of this complexity is hidden within [AsyncNinja](http://async.ninja/), so there is no need to think about it each time.
Just conform your active object to `ExecutionContext` (`UIResponder`/`NSResponder` are automatically conformed to it) and use it.

**Pros**

* `MyService` interface and implementation looks simple
* removes hidden danger
* possibility of deadlocks eliminated

**Cons**

* one more library

I think that all [goals](#goals) are achieved here.

## Summary
I love to pick between multiple variants using math. So:
![Summary](summary.png)

"Refactoring 2.2 - Futures and ExecutionContext" and [AsyncNinja](http://async.ninja/) has the best sum.
