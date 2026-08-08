//
//  EcosystemState.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/2/25.
//

import simd

/// An immutable snapshot of the ecosystem published to observers on every simulation update.
struct EcosystemState {
  /// Per-organism arrays of joint positions.
  let points: [[SIMD2<Float>]]
  /// Per-organism energy levels, parallel to ``points``.
  let energyLevels: [Int32]
  /// Identifiers for each organism, parallel to ``points``.
  let organismIDs: [SimID]
  /// Active shelters in the simulation.
  let shelters: [Shelter]
  /// Current simulation throughput in moves per second.
  let movesPerSecond: Int
}
