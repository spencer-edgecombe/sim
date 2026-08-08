import SwiftUI

/// Configuration values that govern the behavior of the ecosystem simulation.
///
/// Each property maps to a user-facing control in ``ControlView``.
/// Instances are ``Codable`` so they can be persisted via ``SavedControls``.
struct Controls: Codable {
  /// Number of Metal compute iterations executed per simulation step.
  var iterationCount: Int = 1000
  /// Maximum random rotation angle for organism segments, in degrees.
  var movementLimit: Double = 0.01
  /// Length of each organism segment, in points.
  var segmentSize: Float = 10.0
  /// Target canvas refresh rate, in frames per second.
  var refreshRate: Int = 120
  /// Number of organisms created when the simulation resets.
  var organismCount: Int = 100
  /// Minimum organism population; new organisms spawn when the count drops below this value.
  var minOrganismCount: Int = 100
  /// Minimum energy assigned to a newly created organism.
  var minStartingEnergy: Int32 = 10000
  /// Maximum energy assigned to a newly created organism.
  var maxStartingEnergy: Int32 = 100000
  /// Energy gained per iteration while an organism occupies a shelter.
  var shelterEnergyGainRate: Int32 = 1
  /// Number of shelters created when the simulation resets.
  var shelterCount: Int = 10
  /// Energy level at which an organism divides into two.
  var divisionThreshold: Int32 = 200000
  /// Number of movement iterations between shelter position resets. Zero disables resetting.
  var shelterResetInterval: Int = 0
  /// When enabled, organisms that reach zero energy are converted into shelters.
  var deadOrganismsBecomeShelters: Bool = false
}
