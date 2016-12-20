# Steps Towards Nice Asynchronous Code
This article is made to raise awareness about problems related to asynchronous code
and to provide examples solving such problems in a context of programming on Swift 3.0.
*It also mildly advertises [AsyncNinja](http://async.ninja/) library.*

### Contents
* [Let's describe a sample problem](#lets-describe-a-sample-problem)
* [Life Before Asynchronous Code](#life-before-asynchronous-code)
* [Discussion of *"do not forget"*s](#discussion-of-do-not-forgets)
* [Goals for New Approaches](#goals-for-new-approaches)
* [Attempt 1.0 - Async with Callbacks](#attempt-10---async-with-callbacks)
* [Attempt 2.0 - Futures](#attempt-20---futures)
* [Revealing Danger](#revealing-danger)
* [Bugfix 1.1 - Async with Callbacks (full story)](#bugfix-11---async-with-callbacks-full-story)
* [Bugfix 2.1 - Futures (full story)](#bugfix-21---futures-full-story)
* [Refactoring 2.2 - Futures and ExecutionContext](#refactoring-22---futures-and-executioncontext)
* [Summary](#summary)
* [Further Improvements](#further-improvements)

## Let's describe a sample problem

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
    return /*fetch person from network*/
  }
}
```
Pretty straightforward. `input arguments -> output result`. Method can either
return person *(or nil if there is no such person)* or throw issue if something went wrong.
Let's take a look at usage.

```swift
extension MyViewController {
  func present(personWithID identifier: String) {

	/* do not forget to dispatch to background */
    DispatchQueue.global().async {
      do {
        let person = try self.myService.person(identifier: identifier)

        /* do not forget to dispatch to main */
        DispatchQueue.main.async {
          self.present(person: person)
        }
      } catch {

        /* do not forget to dispatch to main */
        DispatchQueue.main.async {
          self.present(error: error)
        }
      }
    }
  }
}
```
Not as beautiful as interface.

**Pros**

* `MyService` interface and implementation looks simple

**Cons**

* possibility of deadlocks in `MyService`
* "do not forget" **x3**
* *hides danger, see [Revealing Danger](#revealing-danger)*

## Discussion of *"do not forget"*s
*IMHO* each of *"do not forget"*s signalizes about poor architecture.  Even if you are
some kind of robot that avoids mistakes in 99% of cases, application with 100
of such calls will have at least one critical issue.

In more realistic conditions such calls are often nested or parallelized
that the triples amount of code, complexity, and chances to make mistake.
And we did not even think of possible deadlocks in `MyService` yet!

## Goals for New Approaches
So let's try to fix issues of this approach. So new approaches have to meet goals:

* avoid possibility of deadlocks
* no "do not forget"s
* provide a reliable way of gluing UI and model together.

## Attempt 1.0 - Async with Callbacks
Since OS X 10.6 and iOS 4.0 we had closures (aka blocks).
Using closures as callback opens another dimension in making asynchronous flows.

```swift
extension MyService {
   func person(identifier: String,
               callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async {
      let person = /*fetch person from network*/

      /* do not forget to add call of callback here */
      callback(person, nil)
    }
  }
}
```
So we are passing callback as last argument. This interface is a little bit uglier.
It looked pure*ish*, but now it is not. Let's see how we will use this interface.

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) { (person, error) in

	  /* do not forget to dispatch to main */
      DispatchQueue.main.async {

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
[Cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity) has rised :(

*For those who see the urge to add `weaks` all over the place. Go to [Revealing Danger](#revealing-danger)*

**Pros**

* fixes 2 "do not forget"s
* possibility of deadlocks eliminated

**Cons**

* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x2**
* *hides danger, see [Revealing Danger](#revealing-danger)*

## Attempt 2.0 - Futures
Let's try one more approach. Idea [futures](https://en.wikipedia.org/wiki/Futures_and_promises) has involved separately. But combination with closures improves futures much.

This is more advanced approach than previous one. So make sure that you read explanations below code if you are unfamiliar with this idea.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) { _ in
      return /*fetch person from network*/
    }
  }
}
```

This interface is almost as good as a synchronous version. 

>
> Short explanation of what has happened.
>
> Call of function `future(executor: ...) { ... }` does two things
> 1. returns `Future<Person>`
> 2. asynchronously executes closure on specified *exectutor*. Returting value from the closure will cause future from (1) to complete
>
> *Executor* is an abstraction that basically describes an object that can execute block, e.g. `DispatchQueue`, `NSManagedObjectContext` and etc.
>
> So we've dispatched execution of "fetch person from network" and returned future 
>

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)

	  /* do not forget to dispatch to main */
      .onComplete(executor: .main) {
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

>
> Short explanation of what has happened.
>
> Call of `self.myService.person(identifier: identifier)` provides `Future<Person>`
> With line `.onComplete(executor: .main) {` we specified reaction on completion of the future.
> `executor: main` means specified closure will be executed on the main executor aka main queue.
> This closure has a single argument `Fallible<Person?>`. `Fallible<T>` is almost like an `Optional<T>` from standard library,
> except it has case `.failure(Error)` instead of `.none`
> So by switching between two available cases we are either presenting a person or presenting an error.
>

**Pros**

* `MyService` interface and implementation looks simple
* fixes 2 "do not forget"s
* possibility of deadlocks eliminated

**Cons**

* one more library
* "do not forget" **x2**
* *hides danger, see [Revealing Danger](#revealing-danger)*

Both interface and implementation look okay. Never the less both approaches hide danger. Let's reveal it.

## Revealing Danger
Let's talk about a lifetime of `MyService` and `MyViewController`. Both of them are *active objects* that
are aware of queues, dispatches, threads and etc.
So here is the scenario:

1. User taps button "Refresh Person Info"
2. `MyViewController` calls method `self.myService.person(identifier: identifier)`
3. `MyService` starts to fetch person from network
4. There are some network issues
5. User does not want to wait for too long, so he is just closing window/popover/modal view/anything
6. The owner of `MyViewController` does not need the view controller anymore. So owner releases reference to view controller assuming that all memory allocated by `MyViewController` will be released
7. `MyViewController` is still retained by closure, so it will retain it's resources until the request completes
8. Request might not complete for a while (depending on networking configs and etc)

**As result**: memory consumption will grow, operations will continue running event if results are not required any more.
We have to fix this because memory and CPU resources are limited.

## Bugfix 1.1 - Async with Callbacks (full story)
The usual fix involves adding `weak`s all over the place.

```swift
extension MyService {
  func person(identifier: String,
              callback: @escaping (Person?, Error?) -> Void) {
	
	/* do not forget weak self */
    self.internalQueue.async { [weak self] in
      guard let strongSelf = self else {

      	/* do not forget to add call of callback here */
        callback(nil, ModelError.serviceIsMissing)
        return
      }

      let person = /*fetch person from network*/

      /* do not forget to add call of callback here */
      callback(person, nil)
    }
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) {

      /* do not forget weak self */
      [weak self] (person, error) in

      /* do not forget to dispatch to main */
      DispatchQueue.main.async {

		/* do not forget weak self */
        [weak self] in
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
This solution definitely fixes described issue but does not meet our [Goals for New Approaches](#goals-for-new-approaches).

**Pros**

* removes hidden danger
* possibility of deadlocks eliminated

**Cons**

* looks ugly
* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x6**

## Bugfix 2.1 - Futures (full story)
Let's apply the fix to futures-based approach. Maybe it will look better here.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) {

      /* do not forget weak self */
      [weak self] _ in
      guard let strongSelf = self
        else { throw ModelError.serviceIsMissing }

      return /*fetch person from network*/
    }
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)

      /* do not forget to dispatch to main */
      .onComplete(executor: .main) {

        /* do not forget weak self */
        [weak self] (personOrError) in
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
I had [Goals for New Approaches](#goals-for-new-approaches) to achieve, so I had to move forward.

## Refactoring 2.2 - Futures and ExecutionContext
Let's make a few assumptions before we explore this approach.

1. for `MyService`
    * `MyService` is an active object that has mutable state
    * This state is allowed to change only on serial queue owned by `MyService`
    * `MyService` owns all operations it initiates, but neither of initiated operations own `MyService`
    * `MyService` communicates with other active objects predominantly using asynchronous calls only
2. for `MyViewController`
    * `MyViewController` is an active object that has mutable state (UI)
    * This state is allowed to change only on the main queue
    * `MyViewController` owns all operations it initiates, but neither of initiated operations own `MyViewController`
    * `MyViewController` communicates with another UI related classes predominantly on the main queue 
    * `MyViewController` communicates with other active objects predominantly using asynchronous calls

So I conclude that `MyService` and `MyViewController` can be conformed to
protocol `ExecutionContext` from [AsyncNinja](http://async.ninja/) library.
That basically means that they can asynchronously execute code that influences their lifetime and internal state.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(context: self) { (self) in
      return /*fetch person from network*/
    }
  }
}
```
>
> Short explanation of what has happened.
>
> `MyService` as mentioned before conforms to `ExecutionContext`. This allows us to call
> `future(context: ...) { ... }` that similar to previously mentioned function that dispatches closure and returns future.
> The key difference between `future(context: ...) { ... }` and `future(executor: ...) { ... }` is that first is contextual.
> It means that execution of closure is bound to that context. Closure will be provided with specified context.
> It means that boilerplate memory management will be done inside `future(context: ...) { ... }` rather then in calling code.
>

```swift
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

>
> Short explanation of what has happened.
>
> `MyViewController` as mentioned before conforms to `ExecutionContext`.
> Call of `self.myService.person(identifier: identifier)` provides `Future<Person>`.
> With line `.onComplete(context: self) {` we've specified reaction on completion of the future.
> `context: self` means that specified closure will be executed on `ExecutionContext`'s
> executor (main queue in this case) if context is still alive.
> This closure has a context and `Fallible<Person?>` as arguments.
>

So as you see, there is no need to think of memory management so often. [AsyncNinja](http://async.ninja/)
encapsulates 99% of this complexity. This must help you to reduce an amount of boilerplate code.
Just conform your active object to `ExecutionContext` and use futures safely.
[AsyncNinja](http://async.ninja/) provides conformance to `ExecutionContext`
for obvious active objects, e.g. `UIResponder`, `NSResponder`, `NSManagedObjectContext` and etc.

**Pros**

* `MyService` interface and implementation looks simple
* removes hidden danger
* possibility of deadlocks eliminated

**Cons**

* one more library

## Summary
I love to pick between multiple variants using math. So:
![Summary](Resources/summary.png)
*[Summary as Numbers Sheet](Resources/summary.numbers.zip)*

Looks like my attempt to achieve all [goals](#goals-for-new-approaches) completed successfully.
I hope you'll find [AsyncNinja](http://async.ninja/) useful too.

If you want to take a deeper look at sample code or experiment yourself
visit [GitHub](https://github.com/AsyncNinja/post-steps-towards-async).

## Further Improvements
Further improvements are possible. This code will look event better with language support (something like `async`, `yield` and etc). But we are not there yet.

Scala for example has this kind of syntactic sugar for futures. Here is an example of combining futures in scala:

```scala
val futureA = Future{...}
val futureB = Future{...}
val futureC = Future{...}

val futureABC = for{
  resultA <- futureA
  resultB <- futureB
  resultC <- futureC
} yield (resultA, resultB, resultC)
```

I personally do not see advantage (maybe just yet). With [AsyncNinja](http://async.ninja/) you can do this:

```swift
let futureA: Future<ResultA> = /* ... */
let futureB: Future<ResultB> = /* ... */
let futureC: Future<ResultC> = /* ... */

let futureABC = zip(futureA, futureB, futureC)
```
