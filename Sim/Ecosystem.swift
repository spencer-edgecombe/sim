//
//  Ecosystem.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import Foundation
import SwiftUI
import Combine

/// The Ecosystem is the main coordinator for the simulation environment.
/// It manages organisms, their movement, and interactions between them.
/// This actor ensures thread-safe access to shared simulation state.
///
/// The ecosystem is responsible for:
/// - Managing organism lifecycle (creation, duplication, merging)
/// - Coordinating organism movement
/// - Handling simulation conditions and updates
/// - Broadcasting state changes to observers
@globalActor
actor Ecosystem {

  // MARK: - Shared Instance

  /// The shared ecosystem instance used throughout the application
  static let shared: Ecosystem = .init()

  // MARK: - Published Properties

  /// The collection of organisms currently in the ecosystem
  var organisms: [Organism] = []
  var points: [SIMD2<Float>] = []

  var ctr = 0
  var lastInterval: Date?
  var updatePointsTask: Task<Void, Never>?

  // MARK: - Private Properties

  /// Task responsible for continuous organism movement
  private var movementTask: Task<Void, Never>?

  /// Set of cancellables for managing subscriptions
  private var cancellables = Set<AnyCancellable>()

  /// Subject for broadcasting ecosystem updates
  private let updateSubject = PassthroughSubject<Void, Never>()
  private let pointsSubject = PassthroughSubject<[[SIMD2<Float>]], Never>()
  private let mpsSubject = PassthroughSubject<Int, Never>()
  

  private var boundary: SIMD2<Float>?
  // MARK: - Initialization

  init() {
  }

  // MARK: - Movement Control

  /// Starts continuous organism movement at the specified frame rate
  func startMoving(
    frameRate: Double,
    chunkSize: Int, 
    updateMovesPerSecond: @escaping (Double) -> Void,
    mpsInterval: Double = 10.0) async {
      stopMoving()
      var ctr = 0
      var lastCtr = 0
      var nextTime = Date().timeIntervalSince1970 + mpsInterval
      let organisms = self.organisms
      let availableCores = ProcessInfo.processInfo.activeProcessorCount
      let organismCount = organisms.count
      let chunkSize = max(1, Int(organismCount / (availableCores * chunkSize)))
      movementTask = Task { [weak self] in
        guard let self else { return }
        while !Task.isCancelled {
          await self.move(chunkSize: chunkSize, organisms: organisms)
          ctr += 1
          if Date().timeIntervalSince1970 > nextTime {
            await mpsSubject.send(Int(Double(ctr - lastCtr) / mpsInterval))
              lastCtr = ctr
              nextTime = Date().timeIntervalSince1970 + mpsInterval
            }
          if ctr % 5 == 0 {
            await updatePoints()
          }
        }
      }
    }

  /// Stops organism movement by cancelling the movement task
  func stopMoving() {
    movementTask?.cancel()
    movementTask = nil
  }

  /// Updates the position of all organisms in the ecosystem
  func move(chunkSize: Int, organisms: [Organism]) async {
    // Pre-fetch boundary and organisms to avoid multiple actor accesses

    // Adjust based on testing
    await withTaskGroup(of: Void.self) { group in
      for chunk in stride(from: 0, to: organisms.count, by: chunkSize) {
        //      for i in organisms.indices {
        let end = min(chunk + chunkSize, organisms.count)
        group.addTask {
          // Process multiple organisms in each task to reduce overhead
          for i in chunk..<end {
            organisms[i].move(boundary: Constants.boundarySIMD2)
            //                        }
          }
        }
      }
      await group.waitForAll()
    }
  }

  func setBoundary(size: SIMD2<Float>) {
    boundary = size
  }

  // MARK: - Simulation Control

  /// Reset the simulation with a new organism configuration
  func reset(length: Float, movementLimit: Double) async {
    stopMoving()
    organisms = []
    let head = SIMD2<Float>(x: 150, y: 100)
    let headSegment = Segment(head: head, angle: nil, length: length, movementLimit: movementLimit)
    let segment2 = Segment(head: headSegment.tail, angle: nil, length: length, movementLimit: movementLimit)
    let segment3 = Segment(head: segment2.tail, angle: nil, length: length, movementLimit: movementLimit)
    let segment4 = Segment(head: segment3.tail, angle: nil, length: length, movementLimit: movementLimit)

    let o = Organism(segments: [headSegment, segment2, segment3, segment4])
    organisms.append(o)
  }

  func addRandomOrganism(
    length: Float,
    movementLimit: Double,
    count: Int = 1
  ) async {
    for i in 0..<count {
      let head = SIMD2<Float>(x: 150, y: 100)
      let segmentCount = Int.random(in: 2...6)
      var lastPoint = head
      var segments: [Segment] = []
      for _ in 0..<segmentCount {
        let segment = Segment(head: lastPoint, angle: nil, length: length, movementLimit: movementLimit)
        segments.append(segment)
        lastPoint = segment.tail
      }
      let organism = Organism(segments: segments)
      organisms.append(organism)
    }
    updateSubject.send()
    updatePoints()
  }

  // MARK: - Organism Management

  /// Creates a duplicate of the specified organism
  func duplicateOrganism(_ organism: Organism) async {
    let duplicate = organism.duplicate()
    organisms.append(duplicate)

    updateSubject.send()
    updatePoints()
  }

  func updatePoints() {
    guard updatePointsTask == nil else {
      return
    }
    let points = organisms.map { $0.points }

    pointsSubject.send(points)
  }

  func updateupdatePointsTask(task: Task<Void, Never>?) {
    updatePointsTask = task
  }

  var pointsPublisher: AnyPublisher<[[SIMD2<Float>]], Never> {
    pointsSubject.eraseToAnyPublisher()
  }

  var mpsPublisher: AnyPublisher<Int, Never> {
    mpsSubject.eraseToAnyPublisher()
  }

  var updatePublisher: AnyPublisher<Void, Never> {
    updateSubject.eraseToAnyPublisher()
  }
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()
  ContentView(viewModel: viewModel)
}
