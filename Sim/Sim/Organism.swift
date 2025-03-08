//
//  Organism.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI

class Organism: Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
  let id: SimID
  
  var segments: [Segment]
  var points: [SIMD2<Float>] = []
  
  /// Counter that increases when an organism is in a shelter and decreases when it's not
  var shelterCounter: Int = 0

  init(segments: [Segment]) {
    assert(!segments.isEmpty)
    self.id = .organism
    self.segments = segments
    
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
  var frame: SIMD4<Float> {
    points.reduce(SIMD4.zero) { $0.union($1) }
  }
}

// MARK: - Utility

extension Organism {
  func duplicate(translation: SIMD2<Float>? = nil) -> Organism {
    let translation = translation ?? .init(frame.width, frame.height)
    return Organism(segments: segments.map { $0.duplicate(translation: translation) })
  }
  
  func grow(angle: Float? = nil, length: Float? = nil) {
    let angle = angle ?? 45 * (.pi / 180)
    let length = length ?? 10
    let segment = Segment(head: points.last!, tail: points.last! + SIMD2<Float>(length * cos(angle), length * sin(angle)), angle: angle)

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
