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

public protocol PersonsProviderOnCallbacks {
  // this method is safe to call from any thread. Callback will be called on undefined thread
  func person(identifier: String,
              callback: @escaping (Person?, Error?) -> Void)

  // has the same behavior as page(identifier:) method,
  // but has more argument will have more sophisticated implementation to provide more close-to-reality experience
  func page(index: Int, personsPerPage: Int, ordering: Ordering,
            callback: @escaping ([Person]?, Error?) -> Void)
}

public extension PersonsProviderOnCallbacks {
  func printPerson(identifier: String) {
    let semaphore = DispatchSemaphore(value: 0)
    var person: Person? = nil
    var failure: Error? = nil
    self.person(identifier: identifier) {
      person = $0
      failure = $1
      semaphore.signal()
    }
    semaphore.wait()

    if let failure = failure {
      print("Did fail to fetch person: \(failure)")
    } else if let person = person {
      print(person)
    } else {
      print("No such person")
    }
  }

  func printPage(index: Int, personsPerPage: Int, ordering: Ordering) {
    let semaphore = DispatchSemaphore(value: 0)
    var persons: [Person]? = nil
    var failure: Error? = nil
    self.page(index: index, personsPerPage: personsPerPage, ordering: ordering) {
      persons = $0
      failure = $1
      semaphore.signal()
    }
    semaphore.wait()

    if let failure = failure {
      print("Did fail to fetch page: \(failure)")
    } else if let persons = persons {
      let lines = persons.map { $0.description }.joined(separator: "\n")
      print(lines)
    } else {
      print("No such page")
    }
  }
}
