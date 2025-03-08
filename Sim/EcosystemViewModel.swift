import SwiftUI
import Combine

/// View model that manages the state and updates of the ecosystem visualization
@MainActor
class EcosystemViewModel: ObservableObject {
  // MARK: - Published Properties
  
  private(set) var points: [[SIMD2<Float>]] = []
  private(set) var path = Path()

  /// Path for drawing shelters on the canvas
  @Published private(set) var shelterPath = Path()

  /// Path for drawing shelters on the canvas
  @Published private(set) var boundaryPath: Path = Path(CGRect(x: 0, y: 0, width: CGFloat(Constants.boundarySIMD2.x), height: CGFloat(Constants.boundarySIMD2.y)))

  /// Shelter entities in the ecosystem
  @Published private(set) var shelters: [Shelter] = []
  
  /// Shelter counters for organisms
  @Published private(set) var shelterCounters: [Int] = []
  
  /// Center points of organisms for counter display
  @Published private(set) var organismCenters: [CGPoint] = []

  @Published var metalIterationCount: Int = 1000

  /// Maximum angle of movement for segments
  @Published var movementLimit: Double = 0.01

  /// Size of each segment in points
  @Published var segmentSize: Float = 10.0

  /// Distance threshold for merging organisms
  @Published var mergeSensitivity: Float = 10.0

  /// Current boundary size of the ecosystem
  @Published var boundary: CGSize = Constants.boundarySIMD2.size

  /// Whether the simulation is currently playing
  @Published var isPlaying: Bool = false

  /// Target frame rate for the simulation
  @Published var frameRate: Int = 750


  /// Target frame rate for the simulation
  @Published var refreshRate: Double = 120

  @Published var organismCount: Int = 100

  @Published var chunkSize: Int = 2

  @Published private(set) var movesPerSecond: Int = 0


  // MARK: - Private Properties
  
  private let ecosystem: Ecosystem
  private var subscriptionTask: Task<Void, Never>?
  var cancellables = Set<AnyCancellable>()

  private let isPlayingSubject = PassthroughSubject<Bool, Never>()
  private let frameRateSubject = PassthroughSubject<Int, Never>()

  // MARK: - Initialization
  
  init(_ ecosystem: Ecosystem = .shared) {
    self.ecosystem = ecosystem

    subscribeToUpdates()
  }

  func subscribeToUpdates() {
    Task {
      var frameRateTask: Task<Void, Never>?
      frameRateSubject
        .debounce(for: 0.1, scheduler: DispatchQueue.main)
        .sink { frameRate in
          frameRateTask?.cancel()
          frameRateTask = Task {
            await self.ecosystem.stopMoving()
            await self.ecosystem.startMoving(
              frameRate: Int(frameRate), 
              chunkSize: Int(self.chunkSize), 
              updateMovesPerSecond: self.updateMovesPerSecond,
              metalIterationCount: UInt32(self.metalIterationCount)
            )
          }
        }
        .store(in: &cancellables)

      var updateMpsTask: Task<Void, Never>?
      await ecosystem.mpsPublisher
        .sink { mps in
          updateMpsTask?.cancel()
          updateMpsTask = Task { @MainActor in
            self.movesPerSecond = mps
          }
        }
        .store(in: &cancellables)
        
      // Subscribe to shelter counter updates
      var updateShelterCountersTask: Task<Void, Never>?
      await ecosystem.shelterCounterPublisher
        .sink { shelterCounters in
          updateShelterCountersTask?.cancel()
          updateShelterCountersTask = Task { @MainActor in
            self.shelterCounters = shelterCounters
          }
        }
        .store(in: &cancellables)
      
      // Subscribe to ecosystem updates to get shelters
      await ecosystem.updatePublisher
        .sink { [weak self] _ in
          Task { @MainActor in
            await self?.updateShelters()
          }
        }
        .store(in: &cancellables)
        
      var updatePointsTask: Task<Void, Never>?
      await ecosystem.pointsPublisher
        .sink { points in
          guard updatePointsTask?.isCancelled != false else {
            return
          }
          updatePointsTask = Task {
            var path = Path()
            var centers: [CGPoint] = []
            
            // Process each organism's points
            for organismPoints in points {
              // Add organism path
              path.move(to: organismPoints.first!.point)
              for simd2 in organismPoints.dropFirst() {
                path.addLine(to: simd2.point)
              }
              
              // Calculate organism center (average of all points)
              if !organismPoints.isEmpty {
                let sum = organismPoints.reduce(SIMD2<Float>.zero) { $0 + $1 }
                let avgX = sum.x / Float(organismPoints.count)
                let avgY = sum.y / Float(organismPoints.count)
                centers.append(CGPoint(x: CGFloat(avgX), y: CGFloat(avgY)))
              }
            }
            
            await MainActor.run {
              self.path = path
              self.organismCenters = centers
            }
            updatePointsTask?.cancel()
          }
        }
        .store(in: &cancellables)
    }
  }

  var wipOrganism: Organism? {
    guard editingWipOrganism else { return nil }
    var lastPoint = wipOrganismStart
    var segments: [Segment] = []
    for i in 1..<wipOrganismNextPointAngle.count {
      let head = lastPoint
      // segment length away from last point at nextPointAngle[i]
      let tail = lastPoint + SIMD2<Float>(cos(Float(wipOrganismNextPointAngle[i])), sin(Float(wipOrganismNextPointAngle[i]))) * Float(segmentSize)
      let segment = Segment(head: head, tail: tail, angle: Float(wipOrganismNextPointAngle[i]))
      segments.append(segment)
      lastPoint = tail
    }
    guard !segments.isEmpty else {
      return nil
    }
    return Organism(segments: segments)
  }
  var wipOrganismStart: SIMD2<Float> {
    .init(Float(wipOrganismStartX), Float(wipOrganismStartY))
  }
  @Published var wipOrganismStartX: Float = 300
  @Published var wipOrganismStartY: Float = 300
  @Published var wipOrganismNextPointAngle: [Float] = [30]
  @Published var wipOrganismMovementAngle: [Float] = [0.01]
  @Published var editingWipOrganism: Bool = false
  
  var wipOrganismPath: Path {
    guard let wipOrganism else { return Path() }
    var path = Path()
    let points = wipOrganism.points
    path.move(to: points.first!.point)
    for point in points.dropFirst() {
      path.addLine(to: point.point)
    }
    return path
  }

  func addWipSegment() {
    wipOrganismNextPointAngle.append(wipOrganismNextPointAngle.last!)
    wipOrganismMovementAngle.append(wipOrganismMovementAngle.last!)
  }


  func addWipOrganism() {
    guard let wipOrganism else { return }
    Task {
      await ecosystem.addOrganism(organism: wipOrganism)
      self.editingWipOrganism = false
    }
  }

  /// Update shelter data and paths
  func updateShelters() async {
    let ecosystemShelters = await ecosystem.getShelters()
    
    // Update shelter data
    shelters = ecosystemShelters
    
    // Create path for rendering shelters
    var shelterPath = Path()
    for shelter in ecosystemShelters {
      let rect = CGRect(
        x: CGFloat(shelter.position.x),
        y: CGFloat(shelter.position.y),
        width: CGFloat(shelter.size.x),
        height: CGFloat(shelter.size.y)
      )
      shelterPath.addRect(rect)
    }
    
    self.shelterPath = shelterPath
  }

  nonisolated lazy var updateMovesPerSecond: (Int) -> Void = { [weak self] movesPerSecond in
    Task { @MainActor in
      self?.movesPerSecond = movesPerSecond
    }
  }

  func addRandomOrganism() {
    Task {
      await ecosystem.addRandomOrganism(length: self.segmentSize, movementLimit: self.movementLimit)
    }
  }
  
  // MARK: - Shelter Management
  
  /// Adds a new shelter to the ecosystem
  func addShelter(position: SIMD2<Float>, size: SIMD2<Float>) {
    Task {
      await ecosystem.addShelter(position: position, size: size)
      await updateShelters()
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
      await updateShelters()
    }
  }

  deinit {
    subscriptionTask?.cancel()
  }
  
  // MARK: - Public Methods
  
  func reset() {
    Task {
      await ecosystem.reset(length: Float(self.segmentSize), movementLimit: self.movementLimit)
      await ecosystem.addRandomShelter(count: 10)
      await ecosystem.addRandomOrganism(length: Float(self.segmentSize), movementLimit: self.movementLimit, count: Int(self.organismCount))
    }
  }
  
  func togglePlayback() {
    isPlaying.toggle()
    Task {
      if isPlaying {
        await ecosystem.startMoving(
          frameRate: self.frameRate, 
          chunkSize: Int(self.chunkSize), 
          updateMovesPerSecond: self.updateMovesPerSecond,
          metalIterationCount: UInt32(self.metalIterationCount)
        )
      } else {
        await ecosystem.stopMoving()
      }
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
        await ecosystem.step(metalIterationCount: UInt32(self.metalIterationCount))
      }
    } else {
      Task {
        // Perform a single step with the current metal iteration count
        await ecosystem.step(metalIterationCount: UInt32(self.metalIterationCount))
      }
    }
  }
}
