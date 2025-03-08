//
//  Point.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI
import simd

// MARK: - SIMD2<Float> Extension

extension SIMD2<Float> {
  
  // MARK: - Rounding and Comparison
  
  /// The granularity used for rounding operations
  static let roughness: Float = 10
  
  /// Returns a string representation of the point with rounded coordinates
  var roughDescription: String {
    return "(" + (~self).x.description + ", " + (~self).y.description + ")"
  }
  
  /// Compares two points after rounding them
  /// - Returns: True if the rounded points are equal
  static func ~= (lhs: SIMD2<Float>, rhs: SIMD2<Float>) -> Bool {
    ~lhs == ~rhs
  }
  
  /// Rounds the point coordinates to the nearest multiple of roughness
  /// - Returns: A new point with rounded coordinates
  static prefix func ~(lhs: SIMD2<Float>) -> SIMD2<Float> {
    let xr = lhs.x.rounded()
    let yr = lhs.y.rounded()
    let x = xr - xr.truncatingRemainder(dividingBy: Self.roughness)
    let y = yr - yr.truncatingRemainder(dividingBy: Self.roughness)
    return SIMD2<Float>(x: x, y: y)
  }
  
  // MARK: - Rotation
  
  /// Rotates the point around the specified origin by the given angle
  /// - Parameters:
  ///   - origin: The point to rotate around
  ///   - cosAngle: The cosine of the rotation angle
  ///   - sinAngle: The sine of the rotation angle
  /// - Returns: A new rotated point
  func rotated(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> SIMD2<Float> {
    SIMD2<Float>(
      x: rotatedX(around: origin, cosAngle: cosAngle, sinAngle: sinAngle) + origin.x,
      y: rotatedY(around: origin, cosAngle: cosAngle, sinAngle: sinAngle) + origin.y
    )
  }
  
  /// Calculates the x-coordinate after rotation
  /// - Parameters:
  ///   - origin: The point to rotate around
  ///   - cosAngle: The cosine of the rotation angle
  ///   - sinAngle: The sine of the rotation angle
  /// - Returns: The rotated x-coordinate
  func rotatedX(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> Float {
    (self.x - origin.x) * cosAngle - (self.y - origin.y) * sinAngle
  }
  
  /// Calculates the y-coordinate after rotation
  /// - Parameters:
  ///   - origin: The point to rotate around
  ///   - cosAngle: The cosine of the rotation angle
  ///   - sinAngle: The sine of the rotation angle
  /// - Returns: The rotated y-coordinate
  func rotatedY(around origin: SIMD2<Float>, cosAngle: Float, sinAngle: Float) -> Float {
    (self.x - origin.x) * sinAngle + (self.y - origin.y) * cosAngle
  }
  
  // MARK: - Conversion and Accessors
  
  /// Converts the SIMD2<Float> to a CGPoint
  var point: CGPoint {
    .init(x: CGFloat(x), y: CGFloat(y))
  }
  
  /// Converts the SIMD2<Float> to a CGSize
  var size: CGSize {
    .init(width: CGFloat(x), height: CGFloat(y))
  }
  
  /// Returns the x component as width
  var width: Float {
    x
  }
  
  /// Returns the y component as height
  var height: Float {
    y
  }
}

extension CGPoint {
  var simd2: SIMD2<Float> {
    .init(Float(x), Float(y))
  }
}

extension CGSize {
  var simd2: SIMD2<Float> {
    .init(Float(width), Float(height))
  }
}

// MARK: - SIMD4 Extension

extension SIMD4 {
  /// Returns the z component as width
  var width: Scalar {
    z
  }
  
  /// Returns the w component as height
  var height: Scalar {
    w
  }
  
  /// Returns a new SIMD4 that is the smallest rectangle containing both this rectangle and the specified point.
  /// - Parameter other: The point to union with this rectangle.
  /// - Returns: The union of the rectangle and the point.
  func union(_ other: SIMD2<Float>) -> SIMD4<Float> where Scalar == Float {
    SIMD4(
      SIMD2(x, other.x).min(),
      SIMD2(y, other.y).min(),
      SIMD2(z, other.x).max(),
      SIMD2(w, other.y).max()
    )
  }
}
