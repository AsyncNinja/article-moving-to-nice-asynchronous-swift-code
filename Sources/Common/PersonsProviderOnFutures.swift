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
import AsyncNinja

public protocol PersonsProviderOnFutures {
  // this method is safe to call from any thread
  func person(identifier: String) -> Future<Person?>

  // has the same behavior as page(identifier:) method,
  // but has more argument will have more sophisticated implementation to provide more close-to-reality experience
  func page(index: Int, personsPerPage: Int, ordering: Ordering) -> Future<[Person]?>
}

public extension PersonsProviderOnFutures {
  func printPerson(identifier: String) {
    switch self.person(identifier: identifier).wait() {
    case .success(.none): print("No such person")
    case .success(.some(let person)): print(person)
    case .failure(let error): print("Did fail to fetch person: \(error)")
    }
  }

  func printPage(index: Int, personsPerPage: Int, ordering: Ordering) {
    switch self.page(index: index, personsPerPage: personsPerPage, ordering: ordering).wait() {
    case .success(.none): print("No such page")
    case .success(.some(let persons)):
      let lines = persons.map { $0.description }.joined(separator: "\n")
      print(lines)
    case .failure(let error): print("Did fail to fetch page: \(error)")
    }
  }
}
