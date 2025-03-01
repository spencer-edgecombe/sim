//
//  Movement.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/23/25.
//

import SwiftUI

struct Movement {
  let angle: Float

  let cosAngle: Float
  let sinAngle: Float

  let negativeCosAngle: Float
  let negativeSinAngle: Float

  init(angle: Float) {
    self.angle = angle
    self.cosAngle = cos(angle)
    self.sinAngle = sin(angle)
    self.negativeCosAngle = cos(-angle)
    self.negativeSinAngle = sin(-angle)
  }

  static func random(in range: ClosedRange<Double>) -> Movement {
    Movement(angle: Float(Angle.degrees(Double.random(in: range)).radians))
  }
}
