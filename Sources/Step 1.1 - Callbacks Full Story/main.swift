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

extension MyService : PersonsProviderOnCallbacks {
  public func person(identifier: String,
                     callback: @escaping (Person?, Error?) -> Void) {
    self.internalQueue.async { [weak self] in
      guard let strongSelf = self else {
        callback(nil, ModelError.serviceIsMissing)
        return
      }

      let person = strongSelf.storage.person(identifier: identifier)
      callback(person, nil)
    }
  }

  public func page(index: Int, personsPerPage: Int, ordering: Ordering,
                   callback: @escaping ([Person]?, Error?) -> Void) {
    self.internalQueue.async { [weak self] in
      guard let strongSelf = self else {
        callback(nil, ModelError.serviceIsMissing)
        return
      }

      do {
        try simulateNetwork()
        let persons = strongSelf.storage.page(index: index, personsPerPage: personsPerPage, ordering: ordering)
        callback(persons, nil)
      } catch {
        callback(nil, error)
      }
    }
  }
}

let myService = MyService(storage: try! Storage.make())
myService.printPerson(identifier: "3")
myService.printPage(index: 4, personsPerPage: 10, ordering: .firstName)
