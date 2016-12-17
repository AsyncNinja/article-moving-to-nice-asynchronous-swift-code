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

do {
  guard let path = ProcessInfo.processInfo.arguments.last else {
    print("Provide initial jsons directory as argument please")
    exit(-1)
  }
  let directoryURL = URL(fileURLWithPath: path, isDirectory: true)
  func readStrings(fileName: String) throws -> [String] {
    let url = directoryURL.appendingPathComponent(fileName)
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data, options: []) as! [String]
  }

  let firstNames = try readStrings(fileName: "firstNames.json")
  let lastNames = try readStrings(fileName: "lastNames.json")
  let placesOfBirth = try readStrings(fileName: "placesOfBirth.json")
  let animals = Animal.Known.all.map(Animal.known)
    + ["horse", "pony", "unicorn", "headcrab"].map(Animal.unknown)

  func makeRandomPerson(index: Int) -> Person {
    let details = Person.Details(placeOfBirth: placesOfBirth.randomElement(), favoriteAnimal: animals.randomElement())
    return Person(identifier: "\(index)",
                  firstName: firstNames.randomElement(),
                  lastName: lastNames.randomElement(),
                  details: details)
  }

  let numberOfPersonsToGenerate = 1000
  let persons = (0..<numberOfPersonsToGenerate).map(makeRandomPerson(index:))
  let data = try JSONSerialization.data(withJSONObject: persons.exportJSON(), options: [.prettyPrinted])
  try data.write(to: directoryURL.appendingPathComponent("persons.json"))
} catch {
  print("Did fail to generate data with error \(error)")
  exit(-1)
}
