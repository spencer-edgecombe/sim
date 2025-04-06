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
  case shelter
}

struct SimID: Hashable, Equatable, CustomStringConvertible, Identifiable {
  var id: SimID {
    self
  }
  
  private static var counters: [IDType: Int] = IDType.allCases.reduce(into: [:]) { result, type in
    result[type] = 0
  }

  private static func count(for type: IDType) -> Int {
    let value = counters[type]!
    counters[type] = value + 1
    return value
  }

  var identifier: String
  private var parentIdentifier: String?
  private var duplicateCount: Int?

  init(type: IDType) {
    self.identifier = "\(type)-\(SimID.count(for: type))"
  }

  private init(identifier: String, parentIdentifier: String?, duplicateCount: Int?) {
    self.identifier = identifier
    self.parentIdentifier = parentIdentifier
    self.duplicateCount = duplicateCount
  }

  func duplicated() -> SimID {
    if let parentId = parentIdentifier {
      // If this is already a duplicate, create a new one with same parent but different count
      return SimID(
        identifier: "\(parentId)-\(duplicateCount! + 1)",
        parentIdentifier: parentId,
        duplicateCount: duplicateCount! + 1
      )
    } else {
      // If this is an original, create first duplicate
      return SimID(
        identifier: "\(identifier)-2",
        parentIdentifier: identifier,
        duplicateCount: 2
      )
    }
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
  
  static var shelter: SimID {
    SimID(type: .shelter)
  }
}
