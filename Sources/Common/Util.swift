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

public protocol JSONConvertible {
  init(json: Any) throws
  func exportJSON() -> Any
}

public extension Array where Element : JSONConvertible {
  init(json: Any) throws {
    guard let array = json as? [Any]
      else { throw ModelError.jsonParsingFailed(Array.self) }
    self = try array.map { try Element(json: $0) }
  }

  func exportJSON() -> Any {
    return self.map { $0.exportJSON() }
  }
}

#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

func generateRandom() -> Int {
  #if os(Linux)
    return random()
  #else
    return Int(arc4random())
  #endif
}

public func simulateNetwork() throws {
  let value = UInt32(generateRandom() % 3)
  guard 0 != value else { // trying to be realistic here
    throw ModelError.simulatedNetworkIssue
  }
  sleep(value)
}

public extension Array {
  func randomElement() -> Iterator.Element {
    let index = generateRandom() % self.count
    return self[index]
  }
}

extension String {
  var expandingTildeInPath: String {
      if let range = self.range(of: "~"), range.lowerBound == self.characters.startIndex {
        var result = self
        result.replaceSubrange(range, with: NSHomeDirectory())
        return result
      } else {
        return self
      }
  }

  var expandingPath: String {
    if let range = self.range(of: "~"), range.lowerBound == self.characters.startIndex {
      var result = self
      result.replaceSubrange(range, with: NSHomeDirectory())
      return result
    } else if self.hasPrefix("/") {
      return self
    } else {
      return FileManager.default.currentDirectoryPath + "/" + self
    }
  }
}
