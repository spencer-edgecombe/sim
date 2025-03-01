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

  init(segments: [Segment]) {
    assert(!segments.isEmpty)
    self.id = .organism
    self.segments = segments
    
    points = [segments.first!.head] + segments.map(\.tail)
  }

  private func updatePoints(_ segments: [Segment]) {
  }

  // Connects two organisms at the head of one organism to a point on the other organism
  private func absorb(_ other: Organism) {
    let otherHeadPoint = other.headSegment.head
    let tailPoint = tail
    
    // Calculate translation before modifying anything
    let translation: SIMD2<Float> = otherHeadPoint - tailPoint
    
    // Translate the other organism's points first
    other.translate(translation)
     other.setHead(tail)
    points.append(contentsOf:  other.points)
    segments.append(contentsOf:  other.segments)
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
  
  func move(boundary: SIMD2<Float>) {
    // Fix the key path syntax and pre-allocate array for better performance
    
    // Forward pass - rotate from head to tail
    for index in segments.indices {
      // Only rotate points after current segment - direct indexing for better performance
      for pointIndex in (index + 1)..<points.count {
        points[pointIndex] = points[pointIndex].rotated(around: points[index], cosAngle: segments[index].movement.cosAngle, sinAngle: segments[index].movement.sinAngle)
      }
    }
    
    // Backward pass - rotate from tail to head
    for i in -(segments.count - 1)...0 {
      
      // Only rotate points before current segment
      for pointIndex in 0...(-i) {
        points[pointIndex] = points[pointIndex].rotated(around: points[-i + 1], cosAngle: segments[-i].movement.negativeCosAngle, sinAngle: segments[-i].movement.negativeSinAngle)
      }
    }
    
    // More efficient boundary check
    var minX = Float.infinity
    var minY = Float.infinity
    var maxX = -Float.infinity
    var maxY = -Float.infinity

    for point in points {
      minX = min(minX, point.x)
      minY = min(minY, point.y)
      maxX = max(maxX, point.x)
      maxY = max(maxY, point.y)
    }
    
    // Calculate translation needed to keep within boundaries

    
    let dx: Float = if minX < 0 {
      -minX
    } else if maxX > Float(boundary.width) {
      Float(boundary.width) - maxX
    } else {
      0
    }

    let dy: Float = if minY < 0 {
      -minY
    } else if maxY > boundary.height {
      boundary.height - maxY
    } else {
      0
    }


    // Apply translation if needed without creating new points
    if dx != 0 || dy != 0 {
      for i in 0..<points.count {
        points[i].x += dx
        points[i].y += dy
      }
    }
  }
}

// MARK: - Properties

extension Organism {
  var frame: SIMD4<Float> {
    points.reduce(SIMD4.zero) { $0.union($1) }
  }
  
  var headSegment: Segment {
    segments.first!
  }
  
  var head: SIMD2<Float> {
    get {
      headSegment.head
    }
  }
  
  func setHead(_ newValue: SIMD2<Float>) {
    segments[0].head = newValue
  }
  
  var tailSegment: Segment {
    segments.last!
  }
  
  var tail: SIMD2<Float> {
    tailSegment.tail
  }
  
  var size: Int {
    segments.count
  }
}

// MARK: - Utility

extension Organism {
  func duplicate(translation: SIMD2<Float>? = nil) -> Organism {
    let translation = translation ?? .init(frame.width, frame.height)
    return Organism(segments: segments.map { $0.duplicate(translation: translation) })
  }
  
//  func grow(angle: Angle? = nil, movement: Movement? = nil) {
//    let segment = Segment(head: tailSegment.tail, angle: angle, movement: movement)
//
//    points.append(segment.tail)
//    segments.append(segment)
//  }



  func translate(_ vector: SIMD2<Float>) {
    for index in points.indices {
      points[index] += vector
    }
  }

}


// MARK: - Operators

extension Organism {
  static func < (lhs: Organism, rhs: Organism)  -> Bool {
     lhs.size < rhs.size
  }
  
  nonisolated static func == (lhs: Organism, rhs: Organism) -> Bool {
    lhs.id == rhs.id
  }
  
  static func ~= (lhs: Organism, rhs: Organism) -> Bool {
    let lhsTail =  lhs.tail
    let lhsHead =  lhs.head
    let rhsTail =  rhs.tail
    let rhsHead =  rhs.head
    return lhsTail ~= rhsHead || lhsHead ~= rhsTail
  }
  
  static func + (lhs: Organism, rhs: Organism)  -> Organism? {
    guard  lhs ~= rhs else { return nil }
    if  lhs.tail ~= rhs.head {
       lhs.absorb(rhs)
      return lhs
    } else {
       rhs.absorb(lhs)
      return rhs
    }
  }
}

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
