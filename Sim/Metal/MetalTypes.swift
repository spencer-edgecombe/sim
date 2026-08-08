//
//  MetalTypes.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/1/25.
//

import simd

/// Per-dispatch metadata passed to the Metal compute kernel alongside segment and point buffers.
///
/// The layout must match the corresponding struct defined in `Segment.metal`.
struct OrganismMetadata {
    /// Total number of points across all organisms in the dispatch.
    var pointCount: UInt32
    /// Simulation boundary dimensions used for edge clamping.
    var boundary: SIMD2<Float>
    /// Number of movement iterations to execute per dispatch.
    var iterationCount: UInt32
    /// Number of shelters present in the shelter buffer.
    var shelterCount: UInt32
    /// Energy gained per iteration while an organism is inside a shelter.
    var energyGainRate: Int32
}
