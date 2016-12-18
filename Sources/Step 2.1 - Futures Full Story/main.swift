//
//  Copyright (c) 2016 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation
import Common
import Dispatch
import AsyncNinja

// implementation PersonsProvider<...> in MyService
extension MyService : PersonsProviderOnFutures {
  public func person(identifier: String) -> Future<Person?> {
    return future(executor: .queue(self.internalQueue)) {
      [weak self] _ in
      guard let strongSelf = self
        else { throw ModelError.serviceIsMissing }
      return strongSelf.storage.person(identifier: identifier)
    }
  }

  public func page(index: Int, personsPerPage: Int, ordering: Ordering) -> Future<[Person]?> {
    return future(executor: .utility, block: simulateNetwork)
      .map(executor: .queue(self.internalQueue)) {
        [weak self] _ in
        guard let strongSelf = self
          else { throw ModelError.serviceIsMissing }
        return strongSelf.storage
          .page(index: index, personsPerPage: personsPerPage, ordering: ordering)
    }
  }
}

// example of usage in UI-related class
extension MyViewController {
  func present(personWithID identifier: String) {
    // let _ = ... looks ugly because AsyncNinja does not provide onCompletion(executor:...) on purpose (see 2.2)
    let _ = self.myService.person(identifier: identifier)
      .mapCompletion(executor: .main) { // remember to dispatch to main
        [weak self] (personOrError) -> Void in // remember weak self
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

let myService = MyService(storage: try! Storage.make())
myService.printPerson(identifier: "3")
myService.printPage(index: 4, personsPerPage: 10, ordering: .firstName)