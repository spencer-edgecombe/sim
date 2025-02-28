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
  var points: [CGPoint] = []

  var movement: [CGVector] = []

  init(segments: [Segment]) {
    assert(!segments.isEmpty)
    self.id = .organism
    self.segments = segments
    points = [segments.first!.head] + segments.map(\.tail)

  }

  private func updateCGPoints(_ segments: [Segment]) {
  }

  // Connects two organisms at the head of one organism to a point on the other organism
  private func absorb(_ other: Organism) {
    let otherHeadCGPoint = other.headSegment.head
    let tailCGPoint = tail
    
    // Calculate translation before modifying anything
    let translation: CGVector = otherHeadCGPoint - tailCGPoint
    
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
  
  func move(boundary: CGSize) {
    // Fix the key path syntax and pre-allocate array for better performance
    var newCGPoints = [CGPoint](repeating: .zero, count: points.count)
    for i in 0..<points.count {
      newCGPoints[i] = points[i]
    }
    
    // Forward pass - rotate from head to tail
    for index in segments.indices {
      // Only rotate points after current segment - direct indexing for better performance
      for pointIndex in (index + 1)..<points.count {
        newCGPoints[pointIndex] = newCGPoints[pointIndex].rotated(angle: segments[index].movement.angle, around: newCGPoints[index])
      }
    }
    
    // Backward pass - rotate from tail to head
    for i in -(segments.count - 1)...0 {
      
      // Only rotate points before current segment
      for pointIndex in 0...(-i) {
        newCGPoints[pointIndex] = newCGPoints[pointIndex].rotated(angle: -segments[-i].movement.angle, around: newCGPoints[-i + 1])
      }
    }
    
    // More efficient boundary check
    var minX = CGFloat.infinity
    var minY = CGFloat.infinity
    var maxX = -CGFloat.infinity
    var maxY = -CGFloat.infinity
    
    for point in newCGPoints {
      minX = min(minX, point.x)
      minY = min(minY, point.y)
      maxX = max(maxX, point.x)
      maxY = max(maxY, point.y)
    }
    
    // Calculate translation needed to keep within boundaries

    
    var dx: CGFloat = if minX < 0 {
      -minX
    } else if maxX > boundary.width {
      boundary.width - maxX
    } else {
      0
    }

    var dy: CGFloat = if minY < 0 {
      -minY
    } else if maxY > boundary.height {
      boundary.height - maxY
    } else {
      0
    }

    // Apply translation if needed without creating new points
    if dx != 0 || dy != 0 {
      for i in 0..<newCGPoints.count {
        newCGPoints[i].x += dx
        newCGPoints[i].y += dy
      }
    }
    
    // Update points in single pass
    for i in points.indices {
      points[i] = newCGPoints[i]
    }
  }
}

// MARK: - Properties

extension Organism {
  var frame: CGRect {
    points.reduce(CGRect.zero) { $0.union(.init(origin: $1, size: .zero)) }
  }
  
  var headSegment: Segment {
    segments.first!
  }
  
  var head: CGPoint {
    get {
      headSegment.head
    }
  }
  
  func setHead(_ newValue: CGPoint) {
    segments[0].head = newValue
  }
  
  var tailSegment: Segment {
    segments.last!
  }
  
  var tail: CGPoint {
    tailSegment.tail
  }
  
  var size: Int {
    segments.count
  }
}

// MARK: - Utility

extension Organism {
  func duplicate(translation: CGVector? = nil) -> Organism {
    let translation = translation ?? .init(dx: frame.width, dy: frame.height)
    return Organism(segments: segments.map { $0.duplicate(translation: translation) })
  }
  
//  func grow(angle: Angle? = nil, movement: Movement? = nil) {
//    let segment = Segment(head: tailSegment.tail, angle: angle, movement: movement)
//
//    points.append(segment.tail)
//    segments.append(segment)
//  }



  func translate(_ vector: CGVector) {
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
