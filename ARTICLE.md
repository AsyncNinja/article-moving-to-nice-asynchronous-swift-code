# Steps Towards Nice Asynchronous Swift Code
This article raises awareness about problems related to asynchronous code
and provides examples of solving them in the context of programming on Swift 3.0.

### Contents
* [Description of a sample problem](#description-of-a-sample-problem)
* [Going back to the sync coding era](#going-back-to-the-sync-coding-era)
	* [About the "do not forget" comment](#about-the-do-not-forget-comment)
	* [About deadlocks](#about-deadlocks)
	* [Summary: Synchronous approach](#summary-synchronous-approach)
* [Acceptance Criteria for New Approaches](#acceptance-criteria-for-new-approaches) 
* [Attempt 1.0. Async with Callbacks](#attempt-10-async-with-callbacks)
* [Attempt 2.0. Futures](#attempt-20-futures)
* [Revealing danger](#revealing-danger)
* [Bugfix 1.1. Async with Callbacks (full story)](#bugfix-11-async-with-callbacks-full-story)
* [Bugfix 2.1. Futures (full story)](#bugfix-21-futures-full-story)
* [Refactoring 2.2. Futures and ExecutionContext](#refactoring-22-futures-and-executioncontext)
    * [Assumptions](#assumptions)
    * [Diving into AsyncNinja implementation](#diving-into-asyncninja-implementation)
    * [Back to Solution](#back-to-solution)
    * [Summary: Refactoring 2.2. Futures and ExecutionContext](#summary-refactoring-22---futures-and-executioncontext)
* [Summary](#summary)
* [Further improvements](#further-improvements)

## Description of a sample problem
Here's the source data:
* `Person` is an example of a struct that contains information about the person.
* `MyService` is an example of a class that serves as an entry point to the model.
* `MyViewController` is an example of a class that manages UI-related instances.

`MyService` must provide `Person` to `MyViewController` in return to the request
with the corresponding identifier. It may not have the requested information in memory,
therefore fetching the person data might involve networking, disk operations, and so on.

## Going back to the sync coding era
I notice that many projects still use the synchronous approach. Thus, let's use it first to resolve our sample problem.

```swift
extension MyService {
  func person(identifier: String) throws -> Person? {
    return /*fetch the person from the network*/
  }
}
```
Seems pretty straightforward: `input arguments -> output result`. This method can either
return the person *(or nil if there is no such a person)* or throw an issue if something has gone wrong.

That's how it looks in use:

```swift
extension MyViewController {
  func present(personWithID identifier: String) {

    /* do not forget to dispatch to the background queue */
    DispatchQueue.global().async {
      do {
        let person = try self.myService.person(identifier: identifier)

        /* do not forget to dispatch to the main queue */
        DispatchQueue.main.async {
          self.present(person: person)
        }
      } catch {

        /* do not forget to dispatch to the main queue */
        DispatchQueue.main.async {
          self.present(error: error)
        }
      }
    }
  }
}
```

As you see, usage of this method doesn't look as beautiful as the interface.

### About the "do not forget" comment
*IMHO*, each *"do not forget"* comment points to a poor architecture. Even if you were
a robot that could've avoid mistakes in 99% of cases, an application with 100
of these calls would have at least one critical issue.

In more realistic conditions, such calls are often nested or parallelized,
which triples the amount of code, complexity, and chances to make a mistake.
Moreover, possible deadlocks in `MyService` have yet to be discussed.

### About deadlocks
[Deadlocks](https://en.wikipedia.org/wiki/Deadlock) are nightmares in programming
that occur in the most unexpected places and under the most unbelievable circumstances.
Make it worse, I can tell from my own experience that 80% of deadlocks are revealed in production.

The code above is synchronous from the perspective of `MyService`.
To perform `func person(identifier: String) throws -> Person?`, we must use a lock at least two times. 
Thus, real world problems substantially increase the complexity of such cases.

There are two possible solutions: either be 100% attentive and careful
or do not use an approach that has such massive issues. As you might have guessed,
we are going to explore option #2.

### Summary: Synchronous approach
**Pros**

* `MyService` interface and implementation looks simple

**Cons**

* possibility of deadlocks in `MyService`
* "do not forget" **x3**
* *hidden danger, see "[Revealing danger](#revealing-danger)"*

## Acceptance Criteria for New Approaches
Now, let's try to find a new coding approach that eliminates all the issues
of the synchronous one. This approach must match the following acceptance criteria: 

* no deadlocks
* no "do not forget"s
* a reliable way of gluing UI and model together.

## Attempt 1.0. Async with Callbacks
We can use closures (aka blocks) as callback starting from OS X 10.6 and iOS 4.0,
which opens another dimension in making asynchronous flows.

```swift
extension MyService {
   func person(identifier: String,
               callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async {
      let person = /*fetch the person from the network*/

      /* do not forget to add a call of the callback here */
      callback(person, nil)
    }
  }
}
```
So, we are passing a callback as the last argument. 
This interface looks a little bit uglier than the previous one.
It looked more like a [pure](https://en.wikipedia.org/wiki/Pure_function) function, but now is not.
Let's check it in-use.

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) {
      (person, error) in

      /* do not forget to dispatch to the main queue */
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
[Cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity) raised :(

*For those who see the urge to add `weaks` all over the place. Go to "[Revealing danger](#revealing-danger)"*

### Summary: Attempt 1.0. Async with Callbacks

**Pros**

* one "do not forget" fixed
* no deadlocks

**Cons**

* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x2**
* *hides danger, see "[Revealing danger](#revealing-danger)"*

## Attempt 2.0. Futures
Let's try one more approach. Idea futures has involved separately. It is a great.
In combination with closures makes this approach even more powerful.

> <[wikipedia](https://en.wikipedia.org/wiki/Futures_and_promises)> ... (futures)
> describe an object that acts as a proxy for a result that is initially unknown,
> usually because the computation of its value is yet incomplete.

This is more advanced approach than previous one. So make sure that you read explanations
below code if you are unfamiliar with this idea.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) {
      return /*fetch the person from network*/
    }
  }
}
```

>
> Short explanation of what has happened.
>
> Call of function `future(executor: ...) { ... }` does two things
>
> 1. returns `Future<Person?>`
> 2. asynchronously executes closure on specified *executor*. Returning value from the closure will cause future to complete
>
> *Executor* is an abstraction that basically describes an object that can execute block,
> e.g. `DispatchQueue`, `NSManagedObjectContext` and etc.
>
> So we've dispatched execution of "fetch the person from network" and returned future.
>

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)

      /* do not forget to dispatch to the main queue */
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
> Call of `self.myService.person(identifier: identifier)` provides `Future<Person?>`.
> With line `.onComplete(executor: .main) {` we've specified reaction on completion of the future.
> `executor: main` means that specified closure will be executed on the main executor aka main queue.
> This closure has a single argument `Fallible<Person?>`. `Fallible<T>` is almost like an `Optional<T>` from standard library,
> except it has case `.failure(Error)` instead of `.none`
> So by switching between two available cases we are either presenting a person (`Person`) or presenting an error.
>

### Summary: Attempt 2.0. Futures

**Pros**

* `MyService` interface and implementation looks simple
* fixes 2 "do not forget"s
* no deadlocks

**Cons**

* one more library
* "do not forget" **x2**
* *hides danger, see "[Revealing danger](#revealing-danger)"*

Both interface and implementation look okay. Never the less both approaches hide danger. Let's reveal it.

***

## Revealing danger
Let's talk about a lifetime of `MyService` and `MyViewController`. Both of them are *active objects* that
are aware of queues, dispatches, threads and etc.
So here is the scenario:

1. User presses button "Refresh Person Info"
2. `MyViewController` calls method `self.myService.person(identifier: identifier)`
3. `MyService` starts to fetch the person from network
4. There are some network issues
5. User does not want to wait for too long, so he/she is just closing window/popover/modal view/anything
6. The owner of `MyViewController` does not need the view controller anymore. So owner releases reference to view controller assuming that all memory allocated by `MyViewController` will be released
7. `MyViewController` is still retained by closure, so it will retain it's resources until the request completes
8. Request might not complete for a while (depending on networking configs and etc)

**As result**: memory consumption will grow, operations will continue running even if there is no need for results anymore.
We have to fix this because memory and CPU resources are limited.

## Bugfix 1.1. Async with Callbacks (full story)
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

      let person = /*fetch the person from network*/

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

      /* do not forget to dispatch to the main queue */
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
This solution definitely fixes described issue but does not meet our [acceptance criteria](#acceptance-criteria-for-new-approaches).

### Summary: Bugfix 1.1. Async with Callbacks (full story)

**Pros**

* removes hidden danger
* no deadlocks

**Cons**

* looks ugly
* adds another kind of "do not forget"
* method output is listed as argument
* "do not forget" **x6**

## Bugfix 2.1. Futures (full story)
Let's apply the fix to futures-based approach. Maybe it will look better here.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) {

      /* do not forget weak self */
      [weak self] _ in
      guard let strongSelf = self
        else { throw ModelError.serviceIsMissing }

      return /*fetch the person from network*/
    }
  }
}

extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)

      /* do not forget to dispatch to the main queue */
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

### Summary: Bugfix 2.1. Futures (full story)

**Pros**

* removes hidden danger
* no deadlocks

**Cons**

* one more library
* adds another kind of "do not forget"
* "do not forget" **x3**

Unfortunately, all libraries I've seen that provide futures for Swift finish here.
We have [acceptance criteria](#acceptance-criteria-for-new-approaches) to achieve, so we must move forward.

***

## Refactoring 2.2. Futures and ExecutionContext
I've been working on concurrency library [AsyncNinja](http://async.ninja/) to achieve these [acceptance criteria](#acceptance-criteria-for-new-approaches).
So we'll explore solutions implemented there. But let's make a few assumptions before we explore this approach.

### Assumptions
1. for `MyService`
    * `MyService` is an active object that has mutable state
    * This state is allowed to change only on serial queue owned by `MyService` (in oppose to locks in synchronous approach)
    * `MyService` owns all operations it initiates, but neither of initiated operations own `MyService`
    * `MyService` communicates with other active objects predominantly using asynchronous calls
2. for `MyViewController`
    * `MyViewController` is an active object that has mutable state (UI)
    * This state is allowed to change only on the main queue (in oppose to locks in synchronous approach)
    * `MyViewController` owns all operations it initiates, but neither of initiated operations own `MyViewController`
    * `MyViewController` communicates with another UI related classes predominantly on the main queue 
    * `MyViewController` communicates with other active objects predominantly using asynchronous calls

So I conclude that `MyService` and `MyViewController` can be conformed to
protocol `ExecutionContext` from [AsyncNinja](http://async.ninja/) library.
That basically means that they can asynchronously execute code that influences their lifetime and internal state.

### Diving into AsyncNinja Implementation
For the further explanation, we'll have to discuss details of [AsyncNinja](http://async.ninja/)'s implementation for a bit. So `ExecutionContext` protocol looks like this:

```swift
public protocol ExecutionContext : class {
  var executor: Executor { get }
  func releaseOnDeinit(_ object: AnyObject)
  func notifyDeinit(_ block: @escaping () -> Void)
}
```
You'll have to have `func releaseOnDeinit(_ object: AnyObject)` and `func notifyDeinit(_ block: @escaping () -> Void)`
methods in order to memory management features. But implementing those for each `ExecutionContext` is a boilerplate code too.
So you can just use another handy protocol that provides implementation of methods for those who have `ReleasePool` instance.

*`ReleasePool` is also [AsyncNinja](http://async.ninja/)'s primitive. It will retain objects until you call `func drain()`.*

```swift
public protocol ReleasePoolOwner {
  var releasePool: ReleasePool { get }
}
```

I agree that it might seem complicated. But do not have to rethink/write this each time.
Let's take a look at the code that you actually have to right in order to conform to `ExecutionContext`:

```swift
class MyService : ExecutionContext, ReleasePoolOwner {
  /* own serial queue */
  let internalQueue = DispatchQueue(label: "my-service-queue")
  
  /* present internal queue as executor */
  var executor: Executor { return .queue(self.internalQueue) }

  /* own release pool */
  let releasePool = ReleasePool()
    
  /* implementation */
}
```

That is it. Three additional lines that you will not forget thanks to Swift's types safety.

[AsyncNinja](http://async.ninja/) also provides conformance to `ExecutionContext`
for obvious active objects, e.g. `UIResponder`, `NSResponder`, `NSManagedObjectContext` and etc,
so there is no need to conform `MyViewController` to `ExecutionContext` manually.

### Back to Solution
Okay. So now we know all of the details. Let's continue with implementation of person fetching and presentation.

```swift
extension MyService {
  func person(identifier: String) -> Future<Person?> {
    return future(context: self) { (self) in
      return /*fetch the person from network*/
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
> It means that execution of closure is bound to context. Closure will be provided with context instance as first argument.
> It means that boilerplate memory management will be done inside `future(context: ...) { ... }` rather then in calling code.
>

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onComplete(context: self) {
        (self, personOrError) in

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
> Call of `self.myService.person(identifier: identifier)` provides `Future<Person?>`.
> With line `.onComplete(context: self) {` we've specified reaction on completion of the future.
> `context: self` means that specified closure will be executed on `ExecutionContext`'s
> executor (main queue in this case) if context is still alive.
> This closure has a context and `Fallible<Person?>` as arguments.
>

So as you see, there is no need to think of memory management so often. [AsyncNinja](http://async.ninja/)
encapsulates 99% of this complexity. This must help you to reduce an amount of boilerplate code.
Just conform your active object to `ExecutionContext` and use futures safely.

### Summary: Refactoring 2.2. Futures and ExecutionContext

**Pros**

* `MyService` interface and implementation looks simple
* removes hidden danger
* no deadlocks

**Cons**

* one more library

## Summary
I love to pick between multiple variants using math. So:
![Summary](Resources/summary.png)
*[Summary as Numbers Sheet](Resources/summary.numbers.zip)*

Looks like our attempt to achieve all [acceptance criteria](#acceptance-criteria-for-new-approaches) completed successfully.
I hope you'll find [AsyncNinja](http://async.ninja/) useful too.

If you want to take a deeper look at sample code or experiment yourself
visit [GitHub](https://github.com/AsyncNinja/post-steps-towards-async).

## Further improvements
Further improvements are possible. This code will look event better with language support (something like `async`, `yield` and etc). But we are not there yet.

Scala for example has syntactic sugar for futures. Here is an example of combining futures in scala:

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

***

I thank everyone who reached down here. You are awesome!

I want to give a shout-out to [MacPaw](https://macpaw.com) for helping me with editing and implementing these ideas.
We will use these findings in next update of [Gemini](https://macpaw.com/gemini) so stay tuned.
