import SwiftUI
import SwiftData

@Model
class SavedControls {
  var name: String
  var controls: Controls?

  init(
    name: String,
    controls: Controls
  ) {
    self.name = name
    self.controls = controls
  }
}

struct Controls: Codable {
  var iterationCount: Int = 1000
  var movementLimit: Double = 0.01
  var segmentSize: Float = 10.0
  var mergeSensitivity: Float = 10.0
  var refreshRate: Int = 120
  var organismCount: Int = 100
  var minOrganismCount: Int = 100
  var minStartingEnergy: Int32 = 10000
  var maxStartingEnergy: Int32 = 100000
  var shelterEnergyGainRate: Int32 = 1
  var shelterCount: Int = 10
  var divisionThreshold: Int32 = 200000
  var shelterResetInterval: Int = 0
  var deadOrganismsBecomeShelters: Bool = false
}

