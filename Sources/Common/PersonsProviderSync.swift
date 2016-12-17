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

public protocol PersonsProviderSync {
  // looks like this method will cause network request, caches invalidation and etc
  // do not call this method on main thread
  func person(identifier: String) throws -> Person?

  // has the same behavior as page(identifier:) method,
  // but has more argument will have more sophisticated implementation to provide more close-to-reality experience
  func page(index: Int, personsPerPage: Int, ordering: Ordering) throws -> [Person]?
}

public extension PersonsProviderSync {
  func printPerson(identifier: String) {
    do {
      guard let person = try self.person(identifier: identifier) else {
        print("No such person")
        return
      }
      print(person)
    } catch {
      print("Did fail to fetch person: \(error)")
    }
  }

  func printPage(index: Int, personsPerPage: Int, ordering: Ordering) {
    do {
      guard let persons = try self.page(index: index, personsPerPage: personsPerPage, ordering: ordering) else {
        print("No such page")
        return
      }
      let lines = persons.map { $0.description }.joined(separator: "\n")
      print(lines)
    } catch {
      print("Did fail to fetch page: \(error)")
    }
  }
}
