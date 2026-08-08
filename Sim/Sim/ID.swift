//
//  ID.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation

/// Categories of identifiable entities in the simulation.
enum IDType: String, Hashable, CaseIterable {
  case organism
  case segment
  case point
  case shelter
}

/// A unique identifier for simulation entities such as organisms, segments, points, and shelters.
///
/// `SimID` maintains per-type auto-incrementing counters to guarantee uniqueness.
/// When an organism duplicates, its duplicate receives a derived identifier that
/// encodes the parent relationship and duplication generation.
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

  /// Returns a new identifier derived from this one, representing a duplicate entity.
  ///
  /// If this identifier is already a duplicate, the returned identifier shares the same
  /// parent but increments the duplication counter.
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

  /// Creates a new organism identifier.
  static var organism: SimID {
    SimID(type: .organism)
  }
  
  /// Creates a new segment identifier.
  static var segment: SimID {
    SimID(type: .segment)
  }
  
  /// Creates a new point identifier.
  static var point: SimID {
    SimID(type: .point)
  }
  
  /// Creates a new shelter identifier.
  static var shelter: SimID {
    SimID(type: .shelter)
  }
}
