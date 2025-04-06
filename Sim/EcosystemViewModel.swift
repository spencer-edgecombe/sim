import SwiftUI
import Combine

/// View model that manages the state and updates of the ecosystem visualization
@MainActor
class EcosystemViewModel: ObservableObject {
  // MARK: - Published Properties
  
  @Published private(set) var path: Path = Path()

  /// Path for drawing shelters on the canvas
  @Published private(set) var shelterPath = Path()

  /// Path for drawing shelters on the canvas
  @Published private(set) var boundaryPath: Path = Path(CGRect(x: 0, y: 0, width: CGFloat(Constants.boundarySIMD2.x), height: CGFloat(Constants.boundarySIMD2.y)))

  @Published private(set) var boundary: CGSize = Constants.boundarySIMD2.size
  @Published private(set) var isPlaying: Bool = false

  /// Controls for the ecosystem
  @Published var controls = Controls()


  @Published private(set) var movesPerSecond: Int = 0

  // MARK: - Private Properties
  
  private let ecosystem: Ecosystem
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization
  
  init(_ ecosystem: Ecosystem = .shared) {
    self.ecosystem = ecosystem
    subscribeToUpdates()
  }

  func subscribeToUpdates() {
    Task {
      await ecosystem.statePublisher
        .receive(on: DispatchQueue.global(qos: .userInteractive))
        .sink { [weak self] state in
          guard let self else { return }

          Task { @MainActor in
            self.movesPerSecond = state.movesPerSecond
          }

          // Update derived UI state
          Task { @MainActor in
            await self.updatePaths(from: state)
          }

        }
        .store(in: &cancellables)
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

  nonisolated lazy var updateMovesPerSecond: (Int) -> Void = { [weak self] movesPerSecond in
    Task { @MainActor in
      self?.movesPerSecond = movesPerSecond
    }
  }

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
    cancellables.forEach { $0.cancel() }
  }
  
  // MARK: - Public Methods
  
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
  
  func togglePlayback() async {
    isPlaying.toggle()
    if isPlaying {
      await ecosystem.startMoving(
        updateMovesPerSecond: self.updateMovesPerSecond,
        metalIterationCount: UInt32(controls.iterationCount),
        energyGainRate: controls.shelterEnergyGainRate
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
