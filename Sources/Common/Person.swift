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

public struct Person : CustomStringConvertible {
  public var identifier: String
  public var firstName: String
  public var lastName: String
  public var canonicalName: String { return "\(self.firstName) \(self.lastName)" }

  public var details: Details?

  public var description: String {
    return "[\(self.identifier)]\t\(self.canonicalName)"
      + (details.flatMap { "; lives in \($0.livesIn); loves \($0.favoriteAnimal)" } ?? "")
  }

  public init(identifier: String, firstName: String, lastName: String, details: Details?) {
    self.identifier = identifier
    self.firstName = firstName
    self.lastName = lastName
    self.details = details
  }

  public struct Details {
    public var livesIn: String
    public var favoriteAnimal: Animal

    public init(placeOfBirth: String, favoriteAnimal: Animal) {
      self.livesIn = placeOfBirth
      self.favoriteAnimal = favoriteAnimal
    }
  }
}

extension Person : JSONConvertible {
  public init(json: Any) throws {
    guard
      let dict = json as? [String:Any],
      let identifier = dict["identifier"] as? String,
      let firstName = dict["firstName"] as? String,
      let lastName = dict["lastName"] as? String
      else { throw ModelError.jsonParsingFailed(Person.self) }

    self.identifier = identifier
    self.firstName = firstName
    self.lastName = lastName
    self.details = try dict["details"].flatMap(Details.init(json:))
  }

  public func exportJSON() -> Any {
    var json: [String:Any] = [
      "identifier" : self.identifier,
      "firstName" : self.firstName,
      "lastName" : self.lastName,
      ]

    if let details = details {
      json["details"] = details.exportJSON()
    }

    return json
  }
}

extension Person.Details : JSONConvertible {
  public init(json: Any) throws {
    guard
      let dict = json as? [String:Any],
      let livesIn = dict["livesIn"] as? String,
      let favoriteAnimalJSON = dict["favoriteAnimal"]
      else { throw ModelError.jsonParsingFailed(Person.Details.self) }

    self.livesIn = livesIn
    self.favoriteAnimal = try Animal(json: favoriteAnimalJSON)
  }

  public func exportJSON() -> Any {
    return [
      "livesIn" : self.livesIn,
      "favoriteAnimal" : self.favoriteAnimal.exportJSON(),
    ]
  }
}
