//
//  CGPoint.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI

// MARK: - CGPoint Extension

extension CGPoint {


  var roughDescription: String {
    return  "(" + (~self).x.description + ", " + (~self).y.description + ")"
  }

  static let roughness: CGFloat = 10

  static func ~= (lhs: CGPoint, rhs: CGPoint) -> Bool {
    ~lhs == ~rhs
  }

  static prefix func ~(lhs: CGPoint) -> CGPoint {
    let xr = lhs.x.rounded()
    let yr = lhs.y.rounded()
    let x = xr - xr.truncatingRemainder(dividingBy: Self.roughness)
    let y = yr - yr.truncatingRemainder(dividingBy: Self.roughness)
    return CGPoint(x: x, y: y)
  }

  static func -(lhs: CGPoint, rhs: CGPoint) -> CGVector {
    CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
  }

  static func +=(lhs: inout CGPoint, rhs: CGVector) {
    lhs.x += rhs.dx
    lhs.y += rhs.dy
  }

  static func +(lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
  }

  static func -=(lhs: inout CGPoint, rhs: CGVector) {
    lhs.x -= rhs.dx
    lhs.y -= rhs.dy
  }

  func rotated(angle: Angle, around origin: CGPoint) -> CGPoint {
    CGPoint(x: rotatedX(CGFloat(angle.radians), around: origin) + origin.x, y: rotatedY(CGFloat(angle.radians), around: origin) + origin.y)
  }

  func rotatedX(_ angle: CGFloat, around origin: CGPoint) -> CGFloat {
    (self.x - origin.x) * cos(angle) - (self.y - origin.y) * sin(angle)
  }


  func rotatedY(_ angle: CGFloat, around origin: CGPoint) -> CGFloat {
    (self.x - origin.x) * sin(angle) + (self.y - origin.y) * cos(angle)
  }
}

