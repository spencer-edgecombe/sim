//
//  Segment.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI
import simd

/// A segment represents a part of an organism with a head and tail point.
/// It stores position data and pre-calculated trigonometric values for efficient rotation operations.
struct Segment {
  // MARK: - Properties
  
  /// The head position of the segment in 2D space
  var head: SIMD2<Float>
  
  /// The tail position of the segment in 2D space
  var tail: SIMD2<Float>
  
  /// Pre-calculated cosine of the rotation angle
  let cosAngle: Float
  
  /// Pre-calculated sine of the rotation angle
  let sinAngle: Float
  
  /// Pre-calculated cosine of the negative rotation angle
  let negativeCosAngle: Float
  
  /// Pre-calculated sine of the negative rotation angle
  let negativeSinAngle: Float

  /// Pre-calculated cosine of the shelter rotation angle
  let shelterCosAngle: Float
  
  /// Pre-calculated sine of the shelter rotation angle
  let shelterSinAngle: Float
  
  /// Pre-calculated cosine of the negative shelter rotation angle
  let shelterNegativeCosAngle: Float
  
  /// Pre-calculated sine of the negative shelter rotation angle
  let shelterNegativeSinAngle: Float

  // MARK: - Basic Initialization
  
  /// Initialize a segment with head, tail, and angles
  /// - Parameters:
  ///   - head: The head position
  ///   - tail: The tail position
  ///   - angle: The rotation angle in radians
  ///   - shelterAngle: The rotation angle to use when in shelter
  init(head: SIMD2<Float>, tail: SIMD2<Float>, angle: Float, shelterAngle: Float) {
    self.head = head
    self.tail = tail
    self.cosAngle = cos(angle)
    self.sinAngle = sin(angle)
    self.negativeCosAngle = cos(-angle)
    self.negativeSinAngle = sin(-angle)
    self.shelterCosAngle = cos(shelterAngle)
    self.shelterSinAngle = sin(shelterAngle)
    self.shelterNegativeCosAngle = cos(-shelterAngle)
    self.shelterNegativeSinAngle = sin(-shelterAngle)
  }

  /// Initialize a segment with pre-calculated trigonometric values
  /// - Parameters:
  ///   - head: The head position
  ///   - tail: The tail position
  ///   - cosAngle: Pre-calculated cosine of the angle
  ///   - sinAngle: Pre-calculated sine of the angle
  ///   - negativeCosAngle: Pre-calculated cosine of the negative angle
  ///   - negativeSinAngle: Pre-calculated sine of the negative angle
  ///   - shelterCosAngle: Pre-calculated cosine of the shelter angle
  ///   - shelterSinAngle: Pre-calculated sine of the shelter angle
  ///   - shelterNegativeCosAngle: Pre-calculated cosine of the negative shelter angle
  ///   - shelterNegativeSinAngle: Pre-calculated sine of the negative shelter angle
  init(
    head: SIMD2<Float>,
    tail: SIMD2<Float>,
    cosAngle: Float,
    sinAngle: Float,
    negativeCosAngle: Float,
    negativeSinAngle: Float,
    shelterCosAngle: Float,
    shelterSinAngle: Float,
    shelterNegativeCosAngle: Float,
    shelterNegativeSinAngle: Float
  ) {
    self.head = head
    self.tail = tail
    self.cosAngle = cosAngle
    self.sinAngle = sinAngle
    self.negativeCosAngle = negativeCosAngle
    self.negativeSinAngle = negativeSinAngle
    self.shelterCosAngle = shelterCosAngle
    self.shelterSinAngle = shelterSinAngle
    self.shelterNegativeCosAngle = shelterNegativeCosAngle
    self.shelterNegativeSinAngle = shelterNegativeSinAngle
  }

  // MARK: - Factory Methods
  
  /// Create a segment with a specified head position, angles, and length
  /// - Parameters:
  ///   - head: The head position
  ///   - angle: Optional angle in radians, randomized within movementLimit if nil
  ///   - shelterAngle: Optional shelter angle in radians, randomized within movementLimit if nil
  ///   - length: The length of the segment
  ///   - movementLimit: The maximum random angle in degrees if angle is nil
  init(
    head: SIMD2<Float>,
    angle: Float?,
    shelterAngle: Float?,
    length: Float,
    movementLimit: Double
  ) {
    let angle = angle ?? Float(Double.random(in: -movementLimit...movementLimit) * (.pi / 180))
    let shelterAngle = shelterAngle ?? Float(Double.random(in: -movementLimit...movementLimit) * (.pi / 180))

    let cosAngle = cos(angle)
    let sinAngle = sin(angle)

    let tail = SIMD2<Float>(x: head.x, y: head.y) + SIMD2<Float>(length * cosAngle, length * sinAngle)

    self.init(head: head, tail: tail, angle: angle, shelterAngle: shelterAngle)
  }

  // MARK: - Utility Methods
  
  /// Creates a duplicate of this segment with a position offset
  /// - Parameter translation: Vector to offset the new segment by
  /// - Returns: A new segment with the same properties but translated position
  func duplicate(translation: SIMD2<Float>) -> Segment {
    Segment(
      head: head + translation,
      tail: tail + translation,
      cosAngle: cosAngle,
      sinAngle: sinAngle,
      negativeCosAngle: negativeCosAngle,
      negativeSinAngle: negativeSinAngle,
      shelterCosAngle: shelterCosAngle,
      shelterSinAngle: shelterSinAngle,
      shelterNegativeCosAngle: shelterNegativeCosAngle,
      shelterNegativeSinAngle: shelterNegativeSinAngle
    )
  }
}



