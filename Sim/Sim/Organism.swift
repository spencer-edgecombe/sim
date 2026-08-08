//
//  Organism.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI
import simd

/// A simulated organism composed of connected ``Segment`` instances.
///
/// Each organism has an energy level that increases while it occupies a ``Shelter``
/// and decreases otherwise. When energy reaches the division threshold the organism
/// duplicates; when energy reaches zero the organism dies.
class Organism: Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
  var id: SimID
  
  /// Ordered segments that form the organism's body.
  var segments: [Segment]
  /// Cached joint positions derived from segment head/tail values.
  var points: [SIMD2<Float>] = []
  
  /// Counter that increases when an organism is in a shelter and decreases when it's not
  var energy: Int32 = 0

  /// Creates an organism from an array of connected segments.
  /// - Parameters:
  ///   - segments: The body segments. Must not be empty.
  ///   - initialEnergy: Starting energy value.
  init(segments: [Segment], initialEnergy: Int32 = 0) {
    assert(!segments.isEmpty)
    self.id = .organism
    self.segments = segments
    self.energy = initialEnergy
    
    points = [segments.first!.head] + segments.map(\.tail)
  }

  nonisolated var description: String {
    // Note: This is now potentially inconsistent since we can't access actor state
    // directly in a nonisolated context. For debug purposes this is acceptable.
    "\(id.identifier): [points...]"
  }
  
  nonisolated var debugDescription: String {
    // Note: This is now potentially inconsistent since we can't access actor state
    // directly in a nonisolated context. For debug purposes this is acceptable.
    "\(id.identifier): [points...]"
  }
}

// MARK: - Properties

extension Organism {
  /// The axis-aligned bounding box that encloses all of the organism's points.
  var frame: simd_float2x2 {
    points.dropFirst().reduce(points.first!.rectangle) { partialResult, point in
      partialResult.union(point)
    }
  }
}

// MARK: - Utility

extension Organism {
  
  /// Creates a copy of this organism, splitting energy equally between the original and the copy.
  /// - Parameter translation: Positional offset applied to the duplicate. Defaults to a fixed offset.
  /// - Returns: A new organism with half the original's energy.
  func duplicate(translation: SIMD2<Float>? = nil) -> Organism {
    let halfEnergy = energy / 2
    energy = halfEnergy // Update original organism's energy
    
    // Calculate a safe translation if none provided
    let safeTranslation = translation ?? SIMD2<Float>(50, 50) // Use fixed offset instead of frame
    
    let duplicateSegments = segments.map { $0.duplicate(translation: safeTranslation) }
    let duplicate = Organism(segments: duplicateSegments, initialEnergy: halfEnergy)
    duplicate.id = id.duplicated() // Use the new duplicated() function
    return duplicate
  }
  
  /// Appends a new segment to the end of the organism.
  /// - Parameters:
  ///   - angle: Rotation angle in radians. Defaults to 45 degrees.
  ///   - shelterAngle: Shelter rotation angle in radians. Defaults to `angle`.
  ///   - length: Segment length in points. Defaults to 10.
  func grow(angle: Float? = nil, shelterAngle: Float? = nil, length: Float? = nil) {
    let angle = angle ?? 45 * (.pi / 180)
    let shelterAngle = shelterAngle ?? angle
    let length = length ?? 10
    let segment = Segment(
      head: points.last!,
      tail: points.last! + SIMD2<Float>(length * cos(angle), length * sin(angle)),
      angle: angle,
      shelterAngle: shelterAngle
    )

    points.append(segment.tail)
    segments.append(segment)
  }

}

#Preview {
  @Previewable @State var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
