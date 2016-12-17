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

public enum Animal : CustomStringConvertible {
  case known(Known)
  case unknown(String)

  public var description: String {
    switch self {
    case let .known(knownAnimal): return knownAnimal.description
    case let .unknown(identifier): return identifier
    }
  }

  public init(identifier: String) {
    self = Known(rawValue: identifier).flatMap(Animal.known)
      ?? .unknown(identifier)
  }

  public enum Known : String, CustomStringConvertible {
    case cat
    case dog
    case mouse
    case hamster
    case rabbit
    case fox
    case bear
    case panda
    case koala
    case tiger
    case lion
    case cow
    case pig
    case frog
    case monkey

    public static let all: [Known] = [
      .cat,
      .dog,
      .mouse,
      .hamster,
      .rabbit,
      .fox,
      .bear,
      .panda,
      .koala,
      .tiger,
      .lion,
      .cow,
      .pig,
      .frog,
      .monkey
    ]

    public var description: String {
      switch self {
      case .cat: return "🐱"
      case .dog: return "🐶"
      case .mouse: return "🐭"
      case .hamster: return "🐹"
      case .rabbit: return "🐰"
      case .fox: return "🦊"
      case .bear: return "🐻"
      case .panda: return "🐼"
      case .koala: return "🐨"
      case .tiger: return "🐯"
      case .lion: return "🦁"
      case .cow: return "🐮"
      case .pig: return "🐷"
      case .frog: return "🐸"
      case .monkey: return "🐵"
      }
    }
  }
}

extension Animal : JSONConvertible {
  public init(json: Any) throws {
    guard let identifier = json as? String
      else { throw ModelError.jsonParsingFailed(Animal.self) }
    self.init(identifier: identifier)
  }

  public func exportJSON() -> Any {
    switch self {
    case let .known(knownAnimal): return knownAnimal.rawValue
    case let .unknown(identifier): return identifier
    }
  }
}
