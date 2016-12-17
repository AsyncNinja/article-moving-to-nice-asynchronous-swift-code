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

public enum Ordering {
  case firstName
  case lastName
  case identifier

  func isGreater(lhs: Person, rhs: Person) -> Bool {
    switch self {
    case .firstName:
      return lhs.firstName < rhs.firstName
    case .lastName:
      return lhs.lastName < rhs.lastName
    case .identifier:
      return lhs.identifier < rhs.identifier
    }
  }
}

public struct Storage {
  let persons: [Person]

  public static func make() throws -> Storage {
    guard let pathToPersonsJSON = ProcessInfo.processInfo.arguments.last else {
      print("Provide path to persons.json please")
      exit(-1)
    }
    let urlToPersonsJSON = URL(fileURLWithPath: pathToPersonsJSON, isDirectory: true)
    let data = try Data(contentsOf: urlToPersonsJSON)
    let json = try JSONSerialization.jsonObject(with: data, options: [])

    return try Storage(personsJSON: json)
  }

  public init(personsJSON: Any) throws {
    self.persons = try Array(json: personsJSON)
  }

  public func page(index: Int, personsPerPage: Int = 10, ordering: Ordering) -> [Person]? {
    let firstPersonIndex = index * personsPerPage
    guard firstPersonIndex < self.persons.count else { return nil }
    let range = firstPersonIndex..<(firstPersonIndex + personsPerPage)
    return self.persons
      .sorted(by: ordering.isGreater)[range]
      .map {
        var person = $0
        person.details = nil // remove details to simulare incomplete records displayed on page
        return person
    }
  }

  public func person(identifier: String) -> Person? {
    return self.persons.first { $0.identifier == identifier }
  }
}
