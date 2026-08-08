//
//  MovesPerSecondBenchmarks.swift
//  SimTests
//
//  Throughput benchmarks for the simulation loop.
//
//  Each benchmark measures how many GPU iterations per second the
//  ecosystem can sustain at a given organism count. The numbers are
//  printed to the test log for direct before/after comparison when
//  evaluating performance optimizations (see
//  `simulation_performance_optimization_12c83003.plan.md`).
//
//  Run all benchmarks and print just the summary lines:
//
//      rm -rf /tmp/sim-bench.xcresult && \
//        xcodebuild test \
//          -project Sim.xcodeproj -scheme Sim \
//          -destination 'platform=macOS,arch=arm64' \
//          -only-testing:SimTests/MovesPerSecondBenchmarks \
//          -resultBundlePath /tmp/sim-bench.xcresult \
//          -quiet && \
//        xcrun xcresulttool get log --type action \
//          --path /tmp/sim-bench.xcresult \
//        | python3 -c "import sys, re; print('\n'.join(sorted(set(re.findall(r'\[mps SUMMARY[^\\\\]+', sys.stdin.read())))))"
//
//  Run a single scale with:
//
//      xcodebuild test \
//        -project Sim.xcodeproj -scheme Sim \
//        -destination 'platform=macOS,arch=arm64' \
//        -only-testing:SimTests/MovesPerSecondBenchmarks/test_mps_100organisms
//

import Foundation
import XCTest

@testable import Sim

/// Throughput benchmarks for the GPU-driven simulation step.
final class MovesPerSecondBenchmarks: XCTestCase {

  // MARK: - Tunables

  /// Energy high enough that no organism dies during a benchmark run
  /// (a single point is 1 energy / 10 iterations) but well below the
  /// default 200_000 division threshold so the population stays fixed.
  private static let benchmarkEnergy: Int32 = 100_000

  /// Number of GPU iterations dispatched per `step()`. Matches the
  /// production default of `Controls.iterationCount`.
  private static let metalIterationCount: UInt32 = 1000

  /// Number of `step()` calls per measurement. Larger = more stable
  /// average, but longer test time. 20 steps × 1000 iterations = 20k
  /// GPU iterations per measurement.
  private static let stepsPerMeasurement: Int = 20

  /// Number of GPU iterations executed before timing begins. Lets
  /// Metal compile pipelines, allocate persistent buffers, and warm
  /// caches so the measurement reflects steady-state throughput.
  private static let warmupSteps: Int = 3

  /// Number of timed measurements per benchmark. More samples = tighter
  /// stddev but longer test time. Matches `XCTestCase.measure`'s default.
  private static let measureIterations: Int = 10

  // MARK: - Benchmarks

  func test_mps_10organisms() async {
    await runBenchmark(organismCount: 10)
  }

  func test_mps_100organisms() async {
    await runBenchmark(organismCount: 100)
  }

  func test_mps_500organisms() async {
    await runBenchmark(organismCount: 500)
  }

  func test_mps_1000organisms() async {
    await runBenchmark(organismCount: 1000)
  }

  // MARK: - Implementation

  /// Runs `stepsPerMeasurement` GPU steps `measureIterations` times,
  /// printing the moves/sec for each iteration plus a one-line summary.
  ///
  /// We don't use `XCTestCase.measure` because it doesn't natively support
  /// `async` work, so we time `step()` calls directly with `ContinuousClock`
  /// and roll our own min/median/avg/max/stddev stats.
  private func runBenchmark(organismCount: Int) async {
    let ecosystem = Ecosystem()
    await ecosystem.addRandomOrganism(
      length: 10,
      movementLimit: 0.05,
      count: organismCount,
      minEnergy: Self.benchmarkEnergy,
      maxEnergy: Self.benchmarkEnergy
    )

    for _ in 0..<Self.warmupSteps {
      await ecosystem.step(
        metalIterationCount: Self.metalIterationCount,
        energyGainRate: 1
      )
    }

    var samples: [Double] = []
    samples.reserveCapacity(Self.measureIterations)

    for iteration in 0..<Self.measureIterations {
      let start = ContinuousClock.now
      for _ in 0..<Self.stepsPerMeasurement {
        await ecosystem.step(
          metalIterationCount: Self.metalIterationCount,
          energyGainRate: 1
        )
      }
      let elapsed = ContinuousClock.now - start
      let elapsedSeconds = Double(elapsed.components.seconds)
        + Double(elapsed.components.attoseconds) / 1e18

      let totalIterations = Double(Self.stepsPerMeasurement) * Double(Self.metalIterationCount)
      let mps = totalIterations / max(elapsedSeconds, .ulpOfOne)
      samples.append(mps)
      print(String(
        format: "[mps organisms=%4d] iter %2d: %10.0f moves/sec  (%5.3fs)",
        organismCount, iteration, mps, elapsedSeconds
      ))
    }

    let avg = samples.reduce(0, +) / Double(samples.count)
    let sorted = samples.sorted()
    let median = sorted[sorted.count / 2]
    let minVal = sorted.first ?? 0
    let maxVal = sorted.last ?? 0
    let stddev = sqrt(samples.map { pow($0 - avg, 2) }.reduce(0, +) / Double(samples.count))

    print(String(
      format: "[mps SUMMARY organisms=%4d] avg=%.0f  median=%.0f  min=%.0f  max=%.0f  stddev=%.0f  moves/sec",
      organismCount, avg, median, minVal, maxVal, stddev
    ))

    XCTAssertGreaterThan(avg, 0, "benchmark must produce positive throughput")

    await ecosystem.stopMoving()
  }
}
