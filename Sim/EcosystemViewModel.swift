import SwiftUI

/// View model that bridges the ``Ecosystem`` actor with SwiftUI, converting simulation
/// state into drawable ``Path`` values and exposing playback controls.
@Observable
@MainActor
class EcosystemViewModel {
  // MARK: - Published Properties
  
  /// Drawable path representing all organism bodies.
  private(set) var path: Path = Path()

  /// Path for drawing shelters on the canvas.
  private(set) var shelterPath = Path()

  /// Path outlining the simulation boundary.
  private(set) var boundaryPath: Path = Path(CGRect(x: 0, y: 0, width: CGFloat(Constants.boundarySIMD2.x), height: CGFloat(Constants.boundarySIMD2.y)))

  /// The size of the simulation boundary.
  private(set) var boundary: CGSize = Constants.boundarySIMD2.size
  /// Whether the simulation is currently running continuously.
  private(set) var isPlaying: Bool = false

  /// Controls for the ecosystem.
  var controls = Controls()

  /// Current simulation throughput in moves per second.
  private(set) var movesPerSecond: Int = 0

  // MARK: - Private Properties
  
  private let ecosystem: Ecosystem
  private var updateTask: Task<Void, Never>?

  // MARK: - Initialization
  
  init(_ ecosystem: Ecosystem = .shared) {
    self.ecosystem = ecosystem
    subscribeToUpdates()
  }

  func subscribeToUpdates() {
    updateTask = Task {
      for await state in await ecosystem.stateStream {
        self.movesPerSecond = state.movesPerSecond
        await self.updatePaths(from: state)
      }
    }
  }
  
  private func updatePaths(from state: EcosystemState) async { 
      var path = Path()
   
      for i in state.points.indices {
        // Add organism path
        path.move(to: state.points[i].first!.point)
        for simd2 in state.points[i].dropFirst() {
            path.addLine(to: simd2.point)
          }
      }
      
    // Update shelter path
    var shelterPath = Path()
    for shelter in state.shelters {
      let rect = CGRect(
        x: CGFloat(shelter.position.x),
        y: CGFloat(shelter.position.y),
        width: CGFloat(shelter.size.x),
        height: CGFloat(shelter.size.y)
      )
      shelterPath.addRect(rect)
    }

    // Calculate color for organism based on energy level
    Task { @MainActor in
      self.path = path
      self.shelterPath = shelterPath
    }
    
    
  }

    @ObservationIgnored nonisolated lazy var updateMovesPerSecond: ((Int) -> Void) = { [weak self] movesPerSecond in
    Task { @MainActor in
      self?.movesPerSecond = movesPerSecond
    }
  }

  /// Adds a single randomly generated organism to the ecosystem using the current control values.
  func addRandomOrganism() {
    Task {
      await ecosystem.addRandomOrganism(
        length: controls.segmentSize, 
        movementLimit: controls.movementLimit,
        minEnergy: controls.minStartingEnergy,
        maxEnergy: controls.maxStartingEnergy
      )
    }
  }
  
  // MARK: - Shelter Management
  
  /// Adds a new shelter to the ecosystem
  func addShelter(position: SIMD2<Float>, size: SIMD2<Float>) {
    Task {
      await ecosystem.addShelter(position: position, size: size)
    }
  }
  
  /// Adds a shelter at a random position
  func addRandomShelter() {
    let position = SIMD2<Float>(
      Float.random(in: 50..<Float(boundary.width) - 150),
      Float.random(in: 50..<Float(boundary.height) - 150)
    )
    let size = SIMD2<Float>(
      Float.random(in: 80...120),
      Float.random(in: 80...120)
    )
    
    Task {
      await ecosystem.addShelter(position: position, size: size)
    }
  }

  deinit {
      var task = Task {
          await updateTask?.cancel()
      }
  }
  
  // MARK: - Public Methods
  
  /// Resets the ecosystem and repopulates it with organisms and shelters based on the current controls.
  func reset() {
    Task {
      await ecosystem.reset(
        length: controls.segmentSize,
        movementLimit: controls.movementLimit,
        divisionThreshold: controls.divisionThreshold,
        shelterResetInterval: controls.shelterResetInterval,
        minOrganismCount: controls.minOrganismCount,
        deadOrganismsBecomeShelters: controls.deadOrganismsBecomeShelters
      )
      await ecosystem.addRandomShelter(count: controls.shelterCount)
      await ecosystem.addRandomOrganism(
        length: controls.segmentSize, 
        movementLimit: controls.movementLimit, 
        count: controls.organismCount,
        minEnergy: controls.minStartingEnergy,
        maxEnergy: controls.maxStartingEnergy
      )
    }
  }
  
  /// Toggles between continuous playback and paused state.
  func togglePlayback() async {
    isPlaying.toggle()
    if isPlaying {
      await ecosystem.startMoving(
        updateMovesPerSecond: self.updateMovesPerSecond,
        metalIterationCount: UInt32(controls.iterationCount),
        energyGainRate: controls.shelterEnergyGainRate,
        refreshRate: controls.refreshRate
      )
    } else {
      await ecosystem.stopMoving()
    }
  }
  
  /// Performs a single step of the simulation
  func step() {
    // Ensure we're not in continuous playback mode
    if isPlaying {
      isPlaying = false
      Task {
        await ecosystem.stopMoving()
        // Perform a single step with the current metal iteration count
        await ecosystem.step(
          metalIterationCount: UInt32(controls.iterationCount),
          energyGainRate: controls.shelterEnergyGainRate
        )
      }
    } else {
      Task {
        // Perform a single step with the current metal iteration count
        await ecosystem.step(
          metalIterationCount: UInt32(controls.iterationCount),
          energyGainRate: controls.shelterEnergyGainRate
        )
      }
    }
  }
}
