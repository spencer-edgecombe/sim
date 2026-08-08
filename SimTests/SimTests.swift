//
//  SimTests.swift
//  SimTests
//
//  Created by Spencer Edgecombe on 2/22/25.
//

import XCTest

@testable import Sim

/// Smoke tests verifying the simulation actually advances when stepped.
///
/// These are not benchmarks — see ``MovesPerSecondBenchmarks`` for throughput
/// measurements used to compare performance optimizations.
final class SimTests: XCTestCase {

  /// Energy high enough that organisms never die during a benchmark window
  /// (energy drops by at most 1 every 10 GPU iterations) but well below the
  /// default 200_000 division threshold so the topology never grows mid-run.
  private static let benchmarkEnergy: Int32 = 100_000

  func test_step_advancesPoints() async {
    let ecosystem = Ecosystem()
    await ecosystem.addRandomOrganism(
      length: 10,
      movementLimit: 0.05,
      count: 5,
      minEnergy: Self.benchmarkEnergy,
      maxEnergy: Self.benchmarkEnergy
    )

    let before = await ecosystem.points
    await ecosystem.step(metalIterationCount: 100, energyGainRate: 1)
    let after = await ecosystem.points

    XCTAssertEqual(before.count, after.count, "step must not change topology")
    XCTAssertNotEqual(before, after, "step must move at least one point")
  }

  func test_step_preservesOrganismCount() async {
    let ecosystem = Ecosystem()
    await ecosystem.addRandomOrganism(
      length: 10,
      movementLimit: 0.05,
      count: 10,
      minEnergy: Self.benchmarkEnergy,
      maxEnergy: Self.benchmarkEnergy
    )

    let before = await ecosystem.organisms.count
    for _ in 0..<5 {
      await ecosystem.step(metalIterationCount: 100, energyGainRate: 1)
    }
    let after = await ecosystem.organisms.count

    XCTAssertEqual(before, after, "no shelters + sub-threshold energy must not divide or kill organisms")
  }
}
