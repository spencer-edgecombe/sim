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
  /// Collection of shelters in the ecosystem
  var shelters: [Shelter] = []

  var ctr = 0
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
  /// Subject for broadcasting shelter counter updates
  private let shelterCounterSubject = PassthroughSubject<[Int], Never>()
  /// Subject for broadcasting organism count changes
  private let organismIDSubject = CurrentValueSubject<[SimID], Never>([])

  // MARK: - Initialization

  init() {
  }

  // MARK: - Movement Control

  /// Starts continuous organism movement at the specified frame rate
  func startMoving(
    frameRate: Int,
    chunkSize: Int,
    updateMovesPerSecond: @escaping (Int) -> Void,
    mpsInterval: Double = 10.0,
    metalIterationCount: UInt32 = 1000
    ) async {
      stopMoving()
      var ctr = 0
      var lastCtr = 0
      var nextTime = Date().timeIntervalSince1970 + mpsInterval

      let organisms = organisms
      let shelters = shelters

      // Use Metal implementation with batch processing
      movementTask = Task { [weak self] in
        guard let self else { return }
        
        // Initialize shelter counters array
        var shelterCounters = organisms.map { $0.shelterCounter }


        while !Task.isCancelled {
          let startTime = Date()
          
          // Capture current state of organisms for Metal processing
          var allPoints: [SIMD2<Float>] = []
          var allSegments: [Segment] = []
          var organismIndices: [UInt32] = [0]
          
          // Prepare data for Metal computation
          for organism in organisms {
            // Add organism points and segments
            allPoints.append(contentsOf: organism.points)
            allSegments.append(contentsOf: organism.segments)
            
            // Track organism boundaries in the indices array
            organismIndices.append(UInt32(allPoints.count))
          }

          // Convert shelters to Metal format
          let metalShelters = shelters.map { shelter -> MetalShelter in
            MetalShelter(position: shelter.position, size: shelter.size)
          }

          let metalController = MetalController.shared

          // Use Metal to process all organisms in parallel with batch processing
          let resultPromise = Task<([SIMD2<Float>], [Int]), Never> { () -> ([SIMD2<Float>], [Int]) in
            return await withCheckedContinuation { continuation in
              metalController.moveOrganisms(
                points: allPoints,
                segments: allSegments,
                organismIndices: organismIndices,
                boundary: Constants.boundarySIMD2,
                shelters: metalShelters,
                shelterCounters: shelterCounters,
                iterationCount: metalIterationCount
              ) { updatedPoints, updatedCounters in
                continuation.resume(returning: (updatedPoints, updatedCounters))
              }
            }
          }
          
          // Wait for Metal computation to complete
          let (updatedPoints, updatedCounters) = await resultPromise.value
          
          // Update organisms with the computed points and shelter counters
          for (i, organism) in organisms.enumerated() {
            let startIndex = Int(organismIndices[i])
            let endIndex = Int(organismIndices[i + 1])
            let pointCount = endIndex - startIndex
            
            // Copy updated points back to the organism
            if startIndex < updatedPoints.count {
              for j in 0..<pointCount {
                if startIndex + j < updatedPoints.count {
                  organism.points[j] = updatedPoints[startIndex + j]
                }
              }
            }
            
            // Update shelter counter
            if i < updatedCounters.count {
              organism.shelterCounter = updatedCounters[i]
            }
          }
          
          // Update shelter counters for next iteration and publish
          shelterCounters = organisms.map { $0.shelterCounter }
          await shelterCounterSubject.send(shelterCounters)
          
          // Update points for visualization
          await updatePoints()
          
          // Since we're doing 1000 iterations per frame, increment the counter by 1000
          ctr += Int(metalIterationCount)
          
          // Calculate and report performance metrics
          let endTime = Date().timeIntervalSince1970
          if endTime > nextTime {
            let elapsed = endTime - nextTime + mpsInterval
            // Multiply by iterations to get true moves per second
            let movesPerSecond = Double(ctr - lastCtr) / elapsed
            updateMovesPerSecond(Int(movesPerSecond))
            lastCtr = ctr
            nextTime = endTime + mpsInterval
          }
          
          // Sleep to maintain the desired frame rate
          let processingTime = Date().timeIntervalSince(startTime)
          let sleepTime = max(0, 1.0 / Double(max(1, frameRate)) - processingTime)

          if sleepTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
          }
        }
      }
    }

  /// Stops organism movement by cancelling the movement task
  func stopMoving() {
    movementTask?.cancel()
    movementTask = nil
  }

  /// Performs a single step of organism movement
  func step(metalIterationCount: UInt32 = 1) async {
    // Ensure we're not already running continuous movement
    stopMoving()
    
    // Capture current state of organisms for Metal processing
    var allPoints: [SIMD2<Float>] = []
    var allSegments: [Segment] = []
    var organismIndices: [UInt32] = [0]
    
    // Prepare data for Metal computation
    for organism in organisms {
      // Add organism points and segments
      allPoints.append(contentsOf: organism.points)
      allSegments.append(contentsOf: organism.segments)
      
      // Track organism boundaries in the indices array
      organismIndices.append(UInt32(allPoints.count))
    }
    
    // Initialize shelter counters array
    var shelterCounters = organisms.map { $0.shelterCounter }

    // Convert shelters to Metal format
    let metalShelters = shelters.map { shelter -> MetalShelter in
      MetalShelter(position: shelter.position, size: shelter.size)
    }

    let metalController = MetalController.shared

    // Use Metal to process all organisms in parallel with batch processing
    let resultPromise = Task<([SIMD2<Float>], [Int]), Never> { () -> ([SIMD2<Float>], [Int]) in
      return await withCheckedContinuation { continuation in
        metalController.moveOrganisms(
          points: allPoints,
          segments: allSegments,
          organismIndices: organismIndices,
          boundary: Constants.boundarySIMD2,
          shelters: metalShelters,
          shelterCounters: shelterCounters,
          iterationCount: metalIterationCount
        ) { updatedPoints, updatedCounters in
          continuation.resume(returning: (updatedPoints, updatedCounters))
        }
      }
    }
    
    // Wait for Metal computation to complete
    let (updatedPoints, updatedCounters) = await resultPromise.value
    
    // Update organisms with the computed points and shelter counters
    for (i, organism) in organisms.enumerated() {
      let startIndex = Int(organismIndices[i])
      let endIndex = Int(organismIndices[i + 1])
      let pointCount = endIndex - startIndex
      
      // Copy updated points back to the organism
      if startIndex < updatedPoints.count {
        for j in 0..<pointCount {
          if startIndex + j < updatedPoints.count {
            organism.points[j] = updatedPoints[startIndex + j]
          }
        }
      }
      
      // Update shelter counter
      if i < updatedCounters.count {
        organism.shelterCounter = updatedCounters[i]
      }
    }
    
    // Update shelter counters for next iteration and publish
    shelterCounters = organisms.map { $0.shelterCounter }
    shelterCounterSubject.send(shelterCounters)
    
    // Update points for visualization
    updatePoints()
  }

  // MARK: - Simulation Control

  /// Reset the simulation with a new organism configuration
  func reset(length: Float, movementLimit: Double) async {
    stopMoving()
    shelters = []
    organisms = []
    let head = SIMD2<Float>(x: 150, y: 100)
    let headSegment = Segment(head: head, angle: nil, length: length, movementLimit: movementLimit)
    let segment2 = Segment(head: headSegment.tail, angle: nil, length: length, movementLimit: movementLimit)
    let segment3 = Segment(head: segment2.tail, angle: nil, length: length, movementLimit: movementLimit)
    let segment4 = Segment(head: segment3.tail, angle: nil, length: length, movementLimit: movementLimit)
    
    let o = Organism(segments: [headSegment, segment2, segment3, segment4])
    organisms.append(o)
    
    // Update organism count
    organismIDSubject.send(organisms.map { $0.id })
  }

  func addRandomOrganism(
    length: Float,
    movementLimit: Double,
    count: Int = 1
  ) async {
    for _ in 0..<count {
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
    
    organismIDSubject.send(organisms.map { $0.id })
  }
  // MARK: - Organism Management

  /// Creates a duplicate of the specified organism
  func duplicateOrganism(_ id: SimID) async {
    guard let index = organisms.firstIndex(where: { $0.id == id }) else {
      return
    }
    let duplicate = organisms[index].duplicate()
    organisms.append(duplicate)

    updateSubject.send()
    updatePoints()
    
    organismIDSubject.send(organisms.map { $0.id })
  }

  func growOrganism(id: SimID) {
    guard let index = organisms.firstIndex(where: { $0.id == id }) else {
      return
    }
    organisms[index].grow()
    updatePoints()
  }

  func updatePoints() {
    guard updatePointsTask == nil else {
      return
    }
    let points = organisms.map { $0.points }

    pointsSubject.send(points)
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
  
  /// Publisher for organism count changes
  var organismIDPublisher: AnyPublisher<[SimID], Never> {
    organismIDSubject.eraseToAnyPublisher()
  }

  // MARK: - Shelter Management
  
  func addOrganism(organism: Organism) {
    organisms.append(organism)
    updateSubject.send()
    updatePoints()
    organismIDSubject.send(organisms.map { $0.id })
  }

  /// Adds a new shelter to the ecosystem
  func addShelter(position: SIMD2<Float>, size: SIMD2<Float>) {
    let shelter = Shelter(position: position, size: size)
    shelters.append(shelter)
    updateSubject.send()
  }
  
  func addRandomShelter(count: Int) {
    for _ in 0..<count {
      let position = SIMD2<Float>(x: Float.random(in: 0...Constants.boundarySIMD2.x), y: Float.random(in: 0...Constants.boundarySIMD2.y))
      let size = SIMD2<Float>(x: Float.random(in: 10...50), y: Float.random(in: 10...50))
       addShelter(position: position, size: size)
    }
    updatePoints()
  }

  /// Returns the current shelters in the ecosystem
  func getShelters() -> [Shelter] {
    return shelters
  }
  
  /// Returns the shelter counter values for all organisms
  func getShelterCounters() -> [Int] {
    return organisms.map { $0.shelterCounter }
  }
  
  /// Publisher for shelter counter updates
  var shelterCounterPublisher: AnyPublisher<[Int], Never> {
    shelterCounterSubject.eraseToAnyPublisher()
  }
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()
  ContentView(viewModel: viewModel)
}
