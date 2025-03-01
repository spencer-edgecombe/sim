//
//  SIMD2<Float>.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI

// MARK: - SIMD2<Float> Extension

extension SIMD2<Float> {


  var roughDescription: String {
    return  "(" + (~self).x.description + ", " + (~self).y.description + ")"
  }

  static let roughness: Float = 10

  static func ~= (lhs: SIMD2<Float>, rhs: SIMD2<Float>) -> Bool {
    ~lhs == ~rhs
  }

  static prefix func ~(lhs: SIMD2<Float>) -> SIMD2<Float> {
    let xr = lhs.x.rounded()
    let yr = lhs.y.rounded()
    let x = xr - xr.truncatingRemainder(dividingBy: Self.roughness)
    let y = yr - yr.truncatingRemainder(dividingBy: Self.roughness)
    return SIMD2<Float>(x: x, y: y)
  }


  func rotated(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> SIMD2<Float> {
    SIMD2<Float>(x: rotatedX(around: origin, cosAngle: cosAngle, sinAngle: sinAngle) + origin.x, y: rotatedY(around: origin, cosAngle: cosAngle, sinAngle: sinAngle) + origin.y)
  }

  func rotatedX(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> Float {
    (self.x - origin.x) * cosAngle - (self.y - origin.y) * sinAngle
  }


  func rotatedY(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> Float {
    (self.x - origin.x) * sinAngle + (self.y - origin.y) * cosAngle
  }

  var point: CGPoint {
    .init(x: CGFloat(x), y: CGFloat(y))
  }

  var size: CGSize {
    .init(width: CGFloat(x), height: CGFloat(y))
  }

  var width: Float {
    x
  }

  var height: Float {
    y
  }
}


extension SIMD4 {
  var width: Scalar {
    z
  }

  var height: Scalar {
    w
  }

  /// Returns a new SIMD4 that is the smallest rectangle containing both this rectangle and the specified rectangle.
  /// - Parameter other: The rectangle to union with this rectangle.
  /// - Returns: The union of the two rectangles.
  func union(_ other: SIMD2<Float>) -> SIMD4<Float> where Scalar == Float {
    SIMD4(SIMD2(x, other.x).min(), SIMD2(y, other.y).min(), SIMD2(x, other.x).max(), SIMD2(y, other.y).max())

  }

}
