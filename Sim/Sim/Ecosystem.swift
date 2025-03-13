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

/// Represents the complete state of the ecosystem at a point in time
struct EcosystemState {
  let points: [[SIMD2<Float>]]
  let energyLevels: [Int32]
  let organismIDs: [SimID]
  let shelters: [Shelter]
  let movesPerSecond: Int
}

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

  /// Subject for broadcasting ecosystem state updates
  private let stateSubject = CurrentValueSubject<EcosystemState, Never>(
    EcosystemState(
      points: [],
      energyLevels: [],
      organismIDs: [],
      shelters: [],
      movesPerSecond: 0
    )
  )
  
  private var lastMpsUpdate = Date()
  private var moveCounter = 0
  private var lastMoveCounter = 0
  private var lastShelterReset = 0
  private var shelterResetInterval: Int = 0

  // MARK: - Initialization

  init() {
  }

  // MARK: - Movement Control

  /// Starts continuous organism movement at the specified frame rate
  func startMoving(
    frameRate: Int,
    updateMovesPerSecond: @escaping (Int) -> Void,
    mpsInterval: Double = 1.0,
    metalIterationCount: UInt32 = 1000,
    energyGainRate: Int32 = 1
  ) async {
    stopMoving()
    var ctr = 0
    var lastCtr = 0
    var nextTime = Date().timeIntervalSince1970 + mpsInterval
    lastShelterReset = moveCounter

    // Remove any organisms with zero energy before starting
    removeDeadOrganisms()
    
    // Only proceed if we have organisms to process
    guard !organisms.isEmpty else { return }

    // Start continuous movement task
    movementTask = Task { [weak self] in
      guard let self else { return }
      
      while !Task.isCancelled {
        let startTime = Date()
        
        // Run a single step of the simulation
        await step(metalIterationCount: metalIterationCount, energyGainRate: energyGainRate)
        
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
  func step(metalIterationCount: UInt32 = 1, energyGainRate: Int32 = 1) async {
    // Only proceed if we have organisms to process
    guard !organisms.isEmpty else { return }
    
    // Increment move counter
    moveCounter += Int(metalIterationCount)
    
    // Check if shelters should be reset
    if shelterResetInterval > 0 && (moveCounter - lastShelterReset) >= shelterResetInterval {
      let currentShelterCount = shelters.count
      shelters = []
      addRandomShelter(count: currentShelterCount)
      lastShelterReset = moveCounter
    }
    
    // Capture current state of organisms for Metal processing
    var allPoints: [SIMD2<Float>] = []
    var allSegments: [Segment] = []
    var pointIndices: [UInt32] = [0]
    var segmentIndices: [UInt32] = [0]
    let organisms = organisms

    // Initialize energy levels array
    let energyLevels = organisms.map { $0.energy }

    // Prepare data for Metal computation
    for organism in organisms {
      // Add organism points and track boundaries
      allPoints.append(contentsOf: organism.points)
      pointIndices.append(UInt32(allPoints.count))
      
      // Add organism segments and track boundaries
      allSegments.append(contentsOf: organism.segments)
      segmentIndices.append(UInt32(allSegments.count))
    }

    // Convert shelters to Metal format
    let metalShelters = shelters.map { shelter -> MetalShelter in
      MetalShelter(position: shelter.position, size: shelter.size)
    }

    let metalController = MetalController.shared
    
    // Wait for Metal computation to complete
    let (updatedPoints, updatedCounters) = await metalController.moveOrganisms(
      points: allPoints,
      segments: allSegments,
      pointIndices: pointIndices,
      segmentIndices: segmentIndices,
      boundary: Constants.boundarySIMD2,
      shelters: metalShelters,
      energyLevels: energyLevels,
      iterationCount: metalIterationCount,
      energyGainRate: energyGainRate
    )

    // Update organisms with the computed points and energy levels
    for (i, organism) in organisms.enumerated() {
      let startPointIndex = Int(pointIndices[i])
      let endPointIndex = Int(pointIndices[i + 1])
      let pointCount = endPointIndex - startPointIndex
      
      // Copy updated points back to the organism
      if startPointIndex < updatedPoints.count {
        for j in 0..<pointCount {
          if startPointIndex + j < updatedPoints.count {
            organism.points[j] = updatedPoints[startPointIndex + j]
          }
        }
      }
      
      // Update energy level
      if i < updatedCounters.count {
        organism.energy = updatedCounters[i]
      }

      // Update segments with new point positions
      for j in 0..<organism.segments.count {
        organism.segments[j].head = organism.points[j]
        organism.segments[j].tail = organism.points[j + 1]
      }
    }
    
    // Check for division threshold and duplicate organisms that qualify
    var newOrganisms: [Organism] = []
    for organism in organisms {
      if organism.energy >= divisionThreshold {
        // Create duplicate with random offset
        let randomOffset = SIMD2<Float>(
          Float.random(in: -50...50),
          Float.random(in: -50...50)
        )
        let duplicate = organism.duplicate(translation: randomOffset)
        newOrganisms.append(duplicate)
      }
    }
    self.organisms.append(contentsOf: newOrganisms)

    // Remove any organisms that have died
    removeDeadOrganisms()
    
    fullUpdate()
  }

  // MARK: - Simulation Control

  /// Reset the simulation with a new organism configuration
  func reset(
    length: Float,
    movementLimit: Double,
    divisionThreshold: Int32 = 200000,
    shelterResetInterval: Int = 0
  ) async {
    stopMoving()
    shelters = []
    organisms = []
    self.divisionThreshold = divisionThreshold
    self.shelterResetInterval = shelterResetInterval
    self.lastShelterReset = moveCounter
    fullUpdate()
  }

  func addRandomOrganism(
    length: Float,
    movementLimit: Double,
    count: Int = 1,
    minEnergy: Int32 = 0,
    maxEnergy: Int32 = 0
  ) {
    for _ in 0..<count {
      let head = SIMD2<Float>(
        x: Float.random(in: 0...Constants.boundarySIMD2.x),
        y: Float.random(in: 0...Constants.boundarySIMD2.y)
      )
      let segmentCount = Int.random(in: 2...6)
      var lastPoint = head
      var segments: [Segment] = []
      for _ in 0..<segmentCount {
        let segment = Segment(
          head: lastPoint,
          angle: nil,
          shelterAngle: nil,
          length: length,
          movementLimit: movementLimit
        )
        segments.append(segment)
        lastPoint = segment.tail
      }
      let initialEnergy = minEnergy == maxEnergy ? minEnergy : Int32.random(in: minEnergy...maxEnergy)
      let organism = Organism(segments: segments, initialEnergy: initialEnergy)
      organisms.append(organism)
    }
    fullUpdate()
  }

  private func fullUpdate(movesPerSecond: Int? = nil) {
    let mps: Int
    if let movesPerSecond {
      mps = movesPerSecond
    } else {
      let now = Date()
      let elapsed = now.timeIntervalSince(lastMpsUpdate)
      if elapsed >= 1.0 {
        mps = Int(Double(moveCounter - lastMoveCounter) / elapsed)
        lastMoveCounter = moveCounter
        lastMpsUpdate = now
      } else {
        mps = stateSubject.value.movesPerSecond
      }
    }
    
    let state = EcosystemState(
      points: organisms.map { $0.points },
      energyLevels: organisms.map { $0.energy },
      organismIDs: organisms.map { $0.id },
      shelters: shelters,
      movesPerSecond: mps
    )
    
    stateSubject.send(state)
  }

  /// Publisher for ecosystem state updates
  var statePublisher: AnyPublisher<EcosystemState, Never> {
    stateSubject
      .removeDuplicates { prev, next in
        // Only emit if there are meaningful changes
        prev.points == next.points &&
        prev.energyLevels == next.energyLevels &&
        prev.organismIDs == next.organismIDs &&
        prev.shelters == next.shelters &&
        prev.movesPerSecond == next.movesPerSecond
      }
      .eraseToAnyPublisher()
  }

  // MARK: - Organism Management

  /// Creates a duplicate of the specified organism
  func duplicateOrganism(_ id: SimID) {
    guard let index = organisms.firstIndex(where: { $0.id == id }) else {
      return
    }
    let duplicate = organisms[index].duplicate()
    organisms.append(duplicate)
    fullUpdate()
  }

  func growOrganism(id: SimID) {
    guard let index = organisms.firstIndex(where: { $0.id == id }) else {
      return
    }
    organisms[index].grow()
    fullUpdate()
  }

  func updatePoints() {
    guard updatePointsTask == nil else {
      return
    }
    fullUpdate()
  }

  private func removeDeadOrganisms() {
    organisms.removeAll { $0.energy <= 0 }
    fullUpdate()
  }

  // MARK: - Shelter Management
  
  func addOrganism(organism: Organism) {
    organisms.append(organism)
    fullUpdate()
  }

  /// Adds a new shelter to the ecosystem
  func addShelter(position: SIMD2<Float>, size: SIMD2<Float>) {
    let shelter = Shelter(position: position, size: size)
    shelters.append(shelter)
    fullUpdate()
  }
  
  func addRandomShelter(count: Int) {
    for _ in 0..<count {
      let position = SIMD2<Float>(x: Float.random(in: 0...Constants.boundarySIMD2.x), y: Float.random(in: 0...Constants.boundarySIMD2.y))
      let size = SIMD2<Float>(x: Float.random(in: 10...50), y: Float.random(in: 10...50))
      addShelter(position: position, size: size)
    }
  }

  /// Returns the current shelters in the ecosystem
  func getShelters() -> [Shelter] {
    return shelters
  }
  
  /// Returns the energy level values for all organisms
  func getEnergyLevels() -> [Int32] {
    return organisms.map { $0.energy }
  }

  private var divisionThreshold: Int32 = 200000
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()
  ContentView(viewModel: viewModel)
}
