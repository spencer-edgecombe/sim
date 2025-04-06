//
//  Organism.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI
import simd

class Organism: Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
  var id: SimID
  
  var segments: [Segment]
  var points: [SIMD2<Float>] = []
  
  /// Counter that increases when an organism is in a shelter and decreases when it's not
  var energy: Int32 = 0

  init(segments: [Segment], initialEnergy: Int32 = 0) {
    assert(!segments.isEmpty)
    self.id = .organism
    self.segments = segments
    self.energy = initialEnergy
    
    points = [segments.first!.head] + segments.map(\.tail)
  }

  private func updatePoints(_ segments: [Segment]) {
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
  var frame: simd_float2x2 {
    points.dropFirst().reduce(points.first!.rectangle) { partialResult, point in
      partialResult.union(point)
    }
  }
}

// MARK: - Utility

extension Organism {
  
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


  func translate(_ vector: SIMD2<Float>) {
    for index in points.indices {
      points[index] += vector
    }
  }

}

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
