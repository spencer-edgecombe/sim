//
//  Ecosystem.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//


import Foundation
import SwiftUI
import Combine
import simd
import Synchronization

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
  /// Flat cache of all organism points used during Metal dispatch.
  var points: [SIMD2<Float>] = []
  var allSegments: [Segment] = []
  var pointIndices: [UInt32] = []
  var segmentIndices: [UInt32] = []
  var energyLevels: [Int32] = []
  /// Collection of shelters in the ecosystem.
  var shelters: [Shelter] = []

  var ctr = 0

  /// Set when organism membership changes (add, divide, die) so the next access
  /// rebuilds `points`, `pointIndices`, `allSegments`, and `segmentIndices` from
  /// the organism array. While `false`, those arrays already reflect the latest
  /// GPU result and can be reused as-is.
  private var topologyDirty: Bool = true

  // MARK: - Private Properties

  /// Task responsible for continuous organism movement
  private var movementTask: Task<Void, Never>?

  /// In-flight Metal dispatch whose result has not yet been folded back into
  /// ecosystem state. Set by ``submitDispatch(...)`` and consumed by
  /// ``drainPendingDispatch()``. While set, the GPU is processing the previous
  /// frame; the CPU is free to do other work (e.g. publish state, update UI).
  ///
  /// This is the core of the double-buffered pipeline: by deferring the
  /// `await` to the start of the *next* `internalStep`, the just-completed
  /// `internalStep` can return immediately and let the outer loop overlap
  /// CPU-side work (`fullUpdate`, control polling) with GPU compute.
  private var pendingDispatch: PendingDispatch?

  /// Per-dispatch state captured at submit time so the drain step can
  /// correctly map results back even if `organisms` mutated during the
  /// intervening `await`. The `Organism` references survive removal because
  /// they are class instances; their `.energy` updates are no-ops once
  /// detached from `self.organisms`.
  private struct PendingDispatch {
    let task: Task<([SIMD2<Float>], [Int32]), Never>
    let organismsSnapshot: [Organism]
  }

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

  private var divisionThreshold: Int32 = 200000
  private var minOrganismCount: Int = 0
  private var deadOrganismsBecomeShelters: Bool = true

  // MARK: - Initialization

  init() {
  }

  // MARK: - Movement Control

  /// Starts continuous organism movement at the specified frame rate
  func startMoving(
    updateMovesPerSecond: @escaping (Int) -> Void,
    mpsInterval: Double = 1.0,
    metalIterationCount: UInt32 = 1000,
    energyGainRate: Int32 = 1,
    refreshRate: Int = 120
  ) async {
    await stopMoving()
    lastShelterReset = moveCounter

    removeDeadOrganisms()
    fullUpdate()
    
    guard !organisms.isEmpty else { return }

    let updateInterval: TimeInterval = 1.0 / Double(refreshRate)
    movementTask = Task { [weak self] in
      guard let self else { return }
      var lastUpdateTime: TimeInterval = 0

      while !Task.isCancelled {
        await internalStep(
          metalIterationCount: metalIterationCount,
          energyGainRate: energyGainRate,
          skipSubmitIfCancelled: { Task.isCancelled }
        )

        let now = Date().timeIntervalSince1970
        if now - lastUpdateTime >= updateInterval {
            await fullUpdate()
          lastUpdateTime = now
        }
      }

      // Drain the trailing in-flight dispatch (if any) so that a subsequent
      // `startMoving`/`step` doesn't pick up a stale pending result.
      await drainPendingDispatch()
    }
  }

  /// Stops organism movement by cancelling the movement task.
  ///
  /// Awaits the cancelled task so its trailing `drainPendingDispatch`
  /// (which awaits the in-flight GPU dispatch) completes before returning.
  /// Without this, a subsequent `startMoving`/`step` could see a stale
  /// pending dispatch.
  func stopMoving() async {
    let task = movementTask
    movementTask = nil
    task?.cancel()
    await task?.value
    // Defensive drain: covers the (rare) path where movement was never
    // started but a pending dispatch was somehow left behind.
    await drainPendingDispatch()
  }

  /// Pipelined simulation step.
  ///
  /// On each call:
  /// 1. **Drain**: `await` the dispatch submitted by the *previous* call (if
  ///    any) and apply its result to ecosystem state (positions, energy,
  ///    division/death).
  /// 2. **Submit**: build the next dispatch's input from the freshly post-
  ///    processed state and submit it to the GPU. This call returns as soon
  ///    as the command buffer is committed -- the GPU keeps running while
  ///    the caller can do CPU-side work (e.g. publish state, run UI).
  ///
  /// The `MetalController` holds two complete buffer sets, so the CPU memcpy
  /// + encode for the new dispatch can use a different buffer than the one
  /// the GPU is still draining for the previous dispatch.
  ///
  /// `skipSubmitIfCancelled`, when supplied, is checked after the drain so
  /// the continuous movement loop can avoid kicking off an extra GPU
  /// dispatch right after `stopMoving` has flipped the cancellation flag.
  private func internalStep(
    metalIterationCount: UInt32 = 1,
    energyGainRate: Int32 = 1,
    skipSubmitIfCancelled: (@Sendable () -> Bool)? = nil
  ) async {
    moveCounter += Int(metalIterationCount)

    if shelterResetInterval > 0 && (moveCounter - lastShelterReset) >= shelterResetInterval {
      let currentShelterCount = shelters.count
      shelters = []
      addRandomShelter(count: currentShelterCount)
      lastShelterReset = moveCounter
    }

    await drainPendingDispatch()

    if let skipSubmitIfCancelled, skipSubmitIfCancelled() {
      return
    }

    submitDispatch(metalIterationCount: metalIterationCount, energyGainRate: energyGainRate)
  }

  /// Awaits the in-flight Metal dispatch (if any) and folds its result back
  /// into ecosystem state. Safe to call when nothing is in flight.
  ///
  /// The drain folds in the GPU result for the *previous* frame, mutates
  /// `organisms` for division/death, and clears `pendingDispatch` so the
  /// next submission starts from a clean slate.
  private func drainPendingDispatch() async {
    guard let pending = pendingDispatch else { return }
    pendingDispatch = nil

    let (updatedPoints, updatedCounters) = await pending.task.value
    let snapshot = pending.organismsSnapshot

    // Mirror the existing single-buffered behavior: assign `points` even if
    // topology was dirtied during the await. The next `rebuildTopologyIfNeeded`
    // will overwrite both `points` and `pointIndices` from the up-to-date
    // organism array, so any transient mismatch never escapes to a reader.
    points = updatedPoints

    // Energy is small and changes externally on division, so write it back.
    // Snapshot indices stay valid because `Organism` is a class -- mutating
    // `.energy` on a removed organism is harmless.
    for (i, organism) in snapshot.enumerated() where i < updatedCounters.count {
      organism.energy = updatedCounters[i]
    }

    // Check for division threshold and duplicate organisms that qualify.
    var anyDivision = false
    for organism in snapshot {
      if organism.energy >= divisionThreshold {
        if !anyDivision {
          markTopologyDirty()
          anyDivision = true
        }
        organisms.append(
          organism.duplicate(
            translation: SIMD2<Float>(
              x: Float.random(in: -10...10),
              y: Float.random(in: -10...10)
            )
          )
        )
      }
    }

    removeDeadOrganisms()
  }

  /// Builds the next dispatch's inputs from current ecosystem state and
  /// submits it via ``MetalController/enqueueMoveOrganisms(...)``. Returns
  /// synchronously after the command buffer has been committed; the GPU
  /// runs asynchronously and its result is collected by the next
  /// ``drainPendingDispatch()``.
  ///
  /// No-op when there are no organisms (nothing to move).
  private func submitDispatch(metalIterationCount: UInt32, energyGainRate: Int32) {
    guard !organisms.isEmpty else { return }

    rebuildTopologyIfNeeded()

    // Energy may change outside the GPU (e.g. division halves it), so rebuild
    // each frame from organism state. Cheap: one Int32 per organism.
    energyLevels.removeAll(keepingCapacity: true)
    energyLevels.reserveCapacity(organisms.count)
    for organism in organisms {
      energyLevels.append(organism.energy)
    }

    let snapshot = organisms
    let task = MetalController.shared.enqueueMoveOrganisms(
      points: points,
      segments: allSegments,
      pointIndices: pointIndices,
      segmentIndices: segmentIndices,
      boundary: Constants.boundarySIMD2,
      shelters: shelters,
      energyLevels: energyLevels,
      iterationCount: metalIterationCount,
      energyGainRate: energyGainRate
    )

    pendingDispatch = PendingDispatch(task: task, organismsSnapshot: snapshot)
  }

  /// Rebuilds the flat topology arrays from `organisms` whenever organism
  /// membership has changed since the last build. While `topologyDirty` is
  /// `false`, `points` already holds the most recent GPU result and the index
  /// arrays still describe a valid layout, so we skip the rebuild entirely.
  private func rebuildTopologyIfNeeded() {
    guard topologyDirty else { return }

    points.removeAll(keepingCapacity: true)
    allSegments.removeAll(keepingCapacity: true)
    pointIndices.removeAll(keepingCapacity: true)
    pointIndices.append(0)
    segmentIndices.removeAll(keepingCapacity: true)
    segmentIndices.append(0)

    for organism in organisms {
      points.append(contentsOf: organism.points)
      pointIndices.append(UInt32(points.count))
      allSegments.append(contentsOf: organism.segments)
      segmentIndices.append(UInt32(allSegments.count))
    }

    topologyDirty = false
  }

  /// Copies the latest GPU-resolved positions for the organism at `i` back into
  /// `organism.points` and the corresponding `segment.head`/`segment.tail`
  /// values. This is only needed for the rare paths that read those properties
  /// directly (division duplication, dead-organism shelter framing).
  /// Falls back to a no-op when the topology arrays don't describe the
  /// organism at `i` (e.g. an organism that was just appended via division).
  private func syncOrganismFromPoints(at i: Int) {
    guard i < organisms.count, i + 1 < pointIndices.count else { return }
    let organism = organisms[i]
    let start = Int(pointIndices[i])
    let end = Int(pointIndices[i + 1])
    guard end <= points.count else { return }
    let pointCount = end - start
    guard pointCount == organism.points.count else { return }

    for j in 0..<pointCount {
      organism.points[j] = points[start + j]
    }
    for j in 0..<organism.segments.count where j + 1 < pointCount {
      organism.segments[j].head = organism.points[j]
      organism.segments[j].tail = organism.points[j + 1]
    }
  }

  /// Marks the topology arrays as needing a rebuild. If the current arrays
  /// still validly describe the existing organisms, first writes their latest
  /// GPU positions back into `organism.points` so the next rebuild starts
  /// from up-to-date data.
  private func markTopologyDirty() {
    guard !topologyDirty else { return }
    let count = min(organisms.count, max(0, pointIndices.count - 1))
    for i in 0..<count {
      syncOrganismFromPoints(at: i)
    }
    topologyDirty = true
  }

  /// Performs a single step of organism movement and waits for it to complete.
  ///
  /// Unlike the pipelined ``internalStep(...)`` used by the continuous
  /// movement loop, `step` drains its own dispatch before returning so
  /// callers (notably tests reading `points` afterwards) observe consistent
  /// state.
  func step(metalIterationCount: UInt32 = 1, energyGainRate: Int32 = 1) async {
    await internalStep(metalIterationCount: metalIterationCount, energyGainRate: energyGainRate)
    await drainPendingDispatch()
    fullUpdate()
  }

  // MARK: - Simulation Control

  /// Reset the simulation with a new organism configuration
  func reset(
    length: Float,
    movementLimit: Double,
    divisionThreshold: Int32 = 200000,
    shelterResetInterval: Int = 0,
    minOrganismCount: Int = 0,
    deadOrganismsBecomeShelters: Bool = true
  ) async {
    await stopMoving()
    shelters = []
    organisms = []
    self.divisionThreshold = divisionThreshold
    self.shelterResetInterval = shelterResetInterval
    self.minOrganismCount = minOrganismCount
    self.deadOrganismsBecomeShelters = deadOrganismsBecomeShelters
    self.lastShelterReset = moveCounter
    topologyDirty = true
    fullUpdate()
  }

  /// Adds one or more randomly generated organisms to the ecosystem.
  /// - Parameters:
  ///   - length: Segment length in points.
  ///   - movementLimit: Maximum random rotation angle in degrees.
  ///   - count: Number of organisms to create.
  ///   - minEnergy: Minimum starting energy.
  ///   - maxEnergy: Maximum starting energy.
  func addRandomOrganism(
    length: Float,
    movementLimit: Double,
    count: Int = 1,
    minEnergy: Int32 = 0,
    maxEnergy: Int32 = 0
  ) {
    // Sync existing organisms' positions back from the GPU buffer before
    // appending so the next rebuild starts from up-to-date data.
    markTopologyDirty()
    organisms.append(contentsOf: (0..<count).map { _ in
    Organism(
        segments: (0..<Int.random(in: 2...6)).reduce(into: [Segment]()) { segments, _ in
          segments.append(Segment(
            head: segments.last?.tail ?? SIMD2<Float>(
              x: Float.random(in: 0...Constants.boundarySIMD2.x),
              y: Float.random(in: 0...Constants.boundarySIMD2.y)
            ),
            angle: nil,
            shelterAngle: nil,
            length: length,
            movementLimit: movementLimit
          ))
        },
        initialEnergy: Int32.random(in: minEnergy...maxEnergy)
      )
    })
    fullUpdate()
  }

  /// Publishes a new ``EcosystemState`` snapshot to all observers.
  /// - Parameter movesPerSecond: Optional override; when `nil`, the value is calculated from elapsed time.
   func fullUpdate(movesPerSecond: Int? = nil) {
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

    // Slice the actor-level `points` buffer (already the latest GPU result)
    // by `pointIndices` to build per-organism point arrays. This avoids
    // reading `organism.points`, which is no longer kept in sync each frame.
    rebuildTopologyIfNeeded()
    var perOrganismPoints: [[SIMD2<Float>]] = []
    perOrganismPoints.reserveCapacity(organisms.count)
    if organisms.count + 1 == pointIndices.count {
      for i in 0..<organisms.count {
        let start = Int(pointIndices[i])
        let end = Int(pointIndices[i + 1])
        if end <= points.count {
          perOrganismPoints.append(Array(points[start..<end]))
        } else {
          perOrganismPoints.append([])
        }
      }
    } else {
      perOrganismPoints = organisms.map { $0.points }
    }

    let state = EcosystemState(
      points: perOrganismPoints,
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
      .eraseToAnyPublisher()
  }

  var stateStream: AsyncStream<EcosystemState> {
    let subject = stateSubject
    return AsyncStream { continuation in
      let cancellable = subject.sink { state in
        continuation.yield(state)
      }
      continuation.onTermination = { _ in
        cancellable.cancel()
      }
    }
  }

  // MARK: - Organism Management

  private func removeDeadOrganisms() {

    // Detect dying organisms and pre-sync everyone before mutating the list,
    // so dying-organism `frame` values come from the latest GPU state and
    // surviving organisms have up-to-date `points` for the next rebuild.
    let hasDying = organisms.contains { $0.energy <= 0 }
    if hasDying {
      markTopologyDirty()
    }

    let newShelters: [Shelter] = organisms.compactMap { organism in
      guard organism.energy == 0 else { return nil }
      let frame: simd_float2x2 = organism.frame
      return deadOrganismsBecomeShelters ? Shelter(position: frame.columns.0, size: frame.columns.1) : nil
    }

    shelters.append(contentsOf: newShelters)

    organisms.removeAll { $0.energy <= 0 }

    // Replenish organisms if count falls below minimum
    if minOrganismCount > 0 && organisms.count < minOrganismCount {
      let countToAdd = minOrganismCount - organisms.count
      for _ in 0..<countToAdd {
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
            length: 10,
            movementLimit: 0.01
          )
          segments.append(segment)
          lastPoint = segment.tail
        }
        let organism = Organism(segments: segments, initialEnergy: 10000)
        organisms.append(organism)
      }
      if countToAdd > 0 {
        markTopologyDirty()
      }
    }
  }

  // MARK: - Shelter Management

  /// Adds a new shelter to the ecosystem
  func addShelter(position: SIMD2<Float>, size: SIMD2<Float>) {
    let shelter = Shelter(position: position, size: size)
    shelters.append(shelter)
    fullUpdate()
  }
  
  /// Adds the specified number of randomly positioned and sized shelters.
  func addRandomShelter(count: Int) {
    for _ in 0..<count {
      let position = SIMD2<Float>(x: Float.random(in: 0...Constants.boundarySIMD2.x), y: Float.random(in: 0...Constants.boundarySIMD2.y))
      let size = SIMD2<Float>(x: Float.random(in: 10...50), y: Float.random(in: 10...50))
      addShelter(position: position, size: size)
    }
  }

}

// MARK: - Preview

#Preview {
  @Previewable @State var viewModel = EcosystemViewModel()
  ContentView(viewModel: viewModel)
}
