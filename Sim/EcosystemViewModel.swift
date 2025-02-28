import SwiftUI
import Combine

/// View model that manages the state and updates of the ecosystem visualization
@MainActor
class EcosystemViewModel: ObservableObject {
  // MARK: - Published Properties
  
  private(set) var points: [[CGPoint]] = []
  private(set) var path = Path()
  /// Maximum angle of movement for segments
  @Published var movementLimit: Double = 0.01

  /// Size of each segment in points
  @Published var segmentSize: Double = 10.0

  /// Distance threshold for merging organisms
  @Published var mergeSensitivity: Double = 10.0

  /// Current boundary size of the ecosystem
  @Published var boundary: CGSize = Constants.boundary

  /// Whether the simulation is currently playing
  @Published var isPlaying: Bool = false

  /// Target frame rate for the simulation
  @Published var frameRate: Double = 750.0


  /// Target frame rate for the simulation
  @Published var refreshRate: Double = 120.0

  @Published var organismCount: Double = 100

  @Published var chunkSize: Double = 2

  @Published private(set) var movesPerSecond: Double = 0


  // MARK: - Private Properties
  
  private let ecosystem: Ecosystem
  private var subscriptionTask: Task<Void, Never>?
  var cancellables = Set<AnyCancellable>()

  private let isPlayingSubject = PassthroughSubject<Bool, Never>()
  private let frameRateSubject = PassthroughSubject<Double, Never>()

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
            await self.ecosystem.startMoving(frameRate: frameRate, chunkSize: Int(self.chunkSize), updateMovesPerSecond: self.updateMovesPerSecond)
          }
        }
        .store(in: &cancellables)

      var updateMpsTask: Task<Void, Never>?
      await ecosystem.mpsPublisher
        .sink { mps in
          updateMpsTask?.cancel()
          updateMpsTask = Task { @MainActor in
            self.movesPerSecond = Double(mps)
          }
        }
        .store(in: &cancellables)
      var updateCGPointsTask: Task<Void, Never>?
      await ecosystem.pointsPublisher
        .sink { points in
          guard updateCGPointsTask?.isCancelled != false else {
            return
          }
          updateCGPointsTask = Task {
            var path = Path()
            for organismCGPoints in points {
              path.move(to: organismCGPoints.first!)
              for point in organismCGPoints.dropFirst() {
                path.addLine(to: point)
              }
            }
            await MainActor.run {
              self.path = path
            }
            updateCGPointsTask?.cancel()
          }
        }
        .store(in: &cancellables)
    }
  }

  nonisolated lazy var updateMovesPerSecond: (Double) -> Void = { [weak self] movesPerSecond in
    Task { @MainActor in
      self?.movesPerSecond = movesPerSecond
    }
  }

  func addRandomOrganism() {
    Task {
      await ecosystem.addRandomOrganism(length: self.segmentSize, movementLimit: self.movementLimit)
    }
  }

  deinit {
    subscriptionTask?.cancel()
  }
  
  // MARK: - Private Methods

  
  // MARK: - Public Methods
  
  
  func reset() {
    Task {
      await ecosystem.reset(length: self.segmentSize, movementLimit: self.movementLimit)
      await ecosystem.addRandomOrganism(length: self.segmentSize, movementLimit: self.movementLimit, count: Int(self.organismCount))
    }
  }
  
  func togglePlayback() {
    isPlaying.toggle()
    Task {
      if isPlaying {
        await ecosystem.startMoving(frameRate: self.frameRate, chunkSize: Int(self.chunkSize), updateMovesPerSecond: self.updateMovesPerSecond)
      } else {
        await ecosystem.stopMoving()
      }
    }
  }
}
