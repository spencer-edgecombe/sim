//
//  ID.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation

enum IDType: String, Hashable, CaseIterable {
  case organism
  case segment
  case point
}

struct SimID: Hashable, Equatable, CustomStringConvertible {
  private static var counters: [IDType: Int] = IDType.allCases.reduce(into: [:]) { result, type in
    result[type] = 0
  }

  private static func count(for type: IDType) -> Int {
    let value = counters[type]!
    counters[type] = value + 1
    return value
  }

  var identifier: String
  init(type: IDType) {
    self.identifier = "\(type)-\(SimID.count(for: type))"
  }

  var description: String {
    identifier
  }

  // Change to static computed properties
  static var organism: SimID {
    SimID(type: .organism)
  }
  
  static var segment: SimID {
    SimID(type: .segment)
  }
  
  static var point: SimID {
    SimID(type: .point)
  }
}
