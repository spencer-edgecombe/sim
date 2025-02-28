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
  var head: CGPoint
  var tail: CGPoint
  var movement: Movement
  
  // MARK: - Initialization
  
  init(head: CGPoint, tail: CGPoint, movement: Movement) {
    self.id = .segment
    self.head = head
    self.tail = tail
    self.movement = movement
  }
  
  // MARK: - Factory Methods
  
  init(
    head: CGPoint,
    angle: Angle?,
    movement: Movement? = nil,
    length: CGFloat,
    movementLimit: CGFloat
    ) {
    let movement = movement ?? .random(in: -movementLimit...movementLimit)
    let angle = angle ?? .degrees(Double(Int.random(in: 0..<8) * 45))
    let x = head.x + length * cos(angle.radians)
    let y = head.y + length * sin(angle.radians)
    let tail = CGPoint(x: x, y: y)
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
  
  func duplicate(translation: CGVector) -> Segment {
    Segment(head: head + translation, tail: tail + translation, movement: movement)
  }
}



