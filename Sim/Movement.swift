//
//  Movement.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/23/25.
//

import SwiftUI

struct Movement {
  let angle: Angle
  
  static func random(in range: ClosedRange<Double>) -> Movement {
    Movement(angle: .degrees(Double.random(in: range)))
  }
}
