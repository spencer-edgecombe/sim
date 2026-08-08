//
//  Shelter.swift
//  Sim
//
//  Created by Spencer Edgecombe on 4/15/25.
//

import Foundation
import SwiftUI

/// A Shelter is a rectangular area where organisms can seek refuge and accumulate a counter value.
struct Shelter: Hashable, Identifiable {
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
  
}

// MARK: - Metal Compatibility

/// Type alias indicating that `Shelter` is directly compatible with the Metal buffer layout.
typealias MetalShelter = Shelter 
