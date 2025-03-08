//
//  Shelter.swift
//  Sim
//
//  Created by Spencer Edgecombe on 4/15/25.
//

import Foundation
import SwiftUI

/// A Shelter is a rectangular area where organisms can seek refuge and accumulate a counter value.
struct Shelter: Identifiable {
  let id: SimID
  
  /// Position of the top-left corner of the shelter
  var position: SIMD2<Float>
  
  /// Size of the shelter
  var size: SIMD2<Float>
  
  init(position: SIMD2<Float>, size: SIMD2<Float>) {
    self.id = .shelter
    self.position = position
    self.size = size
  }
  
  /// Returns whether a point is inside the shelter
  func contains(_ point: SIMD2<Float>) -> Bool {
    let endPosition = position + size
    return point.x >= position.x && point.x <= endPosition.x && 
           point.y >= position.y && point.y <= endPosition.y
  }
}

// MARK: - Metal Compatibility

/// Metal-compatible version of Shelter for passing to compute shaders
struct MetalShelter {
  var position: SIMD2<Float>
  var size: SIMD2<Float>
} 