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
  
  // MARK: - Conversion and Accessors
  
  /// Converts the SIMD2<Float> to a CGPoint
  var point: CGPoint {
    .init(x: CGFloat(x), y: CGFloat(y))
  }
  
  /// Converts the SIMD2<Float> to a CGSize
  var size: CGSize {
    .init(width: CGFloat(x), height: CGFloat(y))
  }

  /// Returns a zero-size rectangle positioned at this point, useful as a starting value for bounding-box calculations.
  var rectangle: simd_float2x2 {
    .init(self, .zero)
  }
}


/// Rectangle helpers that treat a `simd_float2x2` as `(origin, size)`.
extension simd_float2x2 {

  /// The minimum x coordinate (origin x).
  var minX: Float {
    columns.0.x
  }

  /// The minimum y coordinate (origin y).
  var minY: Float {
    columns.0.y
  }

  /// The maximum x coordinate (origin x + width).
  var maxX: Float {
    columns.0.x + columns.1.x
  }

  /// The maximum y coordinate (origin y + height).
  var maxY: Float {
    columns.0.y + columns.1.y
  }
  
  /// Returns a new SIMD4 that is the smallest rectangle containing both this rectangle and the specified point.
  /// - Parameter other: The point to union with this rectangle.
  /// - Returns: The union of the rectangle and the point.
  func union(_ other: SIMD2<Float>) -> simd_float2x2  {
    let minX = SIMD2(minX, other.x).min()
    let minY = SIMD2(minY, other.y).min()
    let maxX = SIMD2(maxX, other.x).max()
    let maxY = SIMD2(maxY, other.y).max()
    return simd_float2x2(
      SIMD2(minX, minY),
      SIMD2(maxX - minX, maxY - minY)
    )
  }
}
