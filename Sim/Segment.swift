//
//  Segment.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI

/// A segment represents a part of an organism with a head and tail point
struct Segment: Identifiable, Hashable {
  let id: SimID
  var head: SIMD2<Float>
  var tail: SIMD2<Float>
  var movement: Movement
  
  // MARK: - Initialization
  
  init(head: SIMD2<Float>, tail: SIMD2<Float>, movement: Movement) {
    self.id = .segment
    self.head = head
    self.tail = tail
    self.movement = movement
  }
  
  // MARK: - Factory Methods
  
  init(
    head: SIMD2<Float>,
    angle: Float?,
    movement: Movement? = nil,
    length: Float,
    movementLimit: Double
    ) {
      let movement = movement ?? Movement.random(in: -movementLimit...movementLimit)
      let x = head.x + length * movement.cosAngle
      let y = head.y + length * movement.sinAngle
    let tail = SIMD2<Float>(x: x, y: y)
    self.init(head: head, tail: tail, movement: movement)
  }
  
  // MARK: - Hashable
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  static func == (lhs: Segment, rhs: Segment) -> Bool {
    lhs.id == rhs.id
  }
  
  // MARK: - Utility Methods
  
  func duplicate(translation: SIMD2<Float>) -> Segment {
    Segment(head: head + translation, tail: tail + translation, movement: movement)
  }
}



