//
//  MetalController.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/1/25.
//

import Metal
import MetalKit
import Foundation

class MetalController {
  static let shared: MetalController = MetalController()!
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    // Compute pipeline state for organism movement
    private var moveOrganismsPipelineState: MTLComputePipelineState?

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }

        self.device = device
        self.commandQueue = queue
        self.library = library
        
        // Create the compute pipeline for organism movement
        if let moveOrganismsFunction = library.makeFunction(name: "moveOrganisms") {
            do {
                moveOrganismsPipelineState = try device.makeComputePipelineState(function: moveOrganismsFunction)
            } catch {
                print("Error creating move organisms compute pipeline: \(error)")
            }
        }
    }
    
    // Method to move organisms using Metal
    func moveOrganisms(
        points: [SIMD2<Float>],
        segments: [Segment],
        pointIndices: [UInt32],
        segmentIndices: [UInt32],
        boundary: SIMD2<Float>,
        shelters: [MetalShelter] = [],
        energyLevels: [Int32] = [],
        iterationCount: UInt32 = 1,
        energyGainRate: Int32 = 1
    ) async -> ([SIMD2<Float>], [Int32]) {
        return await withCheckedContinuation { continuation in
          guard let pipelineState = moveOrganismsPipelineState,
                !points.isEmpty,
                !segments.isEmpty,
                pointIndices.count > 1,
                segmentIndices.count > 1 else {
            continuation.resume(returning: (points, energyLevels))
            return
          }

          // Create buffers
          let pointsBuffer = device.makeBuffer(bytes: points, length: points.count * MemoryLayout<SIMD2<Float>>.stride, options: .storageModeShared)

          // Convert segments to metal-friendly format
          var metalSegments = segments.map { segment -> MetalSegment in
            MetalSegment(
              head: segment.head,
              tail: segment.tail,
              cosAngle: segment.cosAngle,
              sinAngle: segment.sinAngle,
              negativeCosAngle: segment.negativeCosAngle,
              negativeSinAngle: segment.negativeSinAngle,
              shelterCosAngle: segment.shelterCosAngle,
              shelterSinAngle: segment.shelterSinAngle,
              shelterNegativeCosAngle: segment.shelterNegativeCosAngle,
              shelterNegativeSinAngle: segment.shelterNegativeSinAngle
            )
          }

          let segmentsBuffer = device.makeBuffer(
            bytes: &metalSegments,
            length: metalSegments.count * MemoryLayout<MetalSegment>.stride,
            options: .storageModeShared
          )

          // Create point indices buffer
          var pointIndicesArray = pointIndices
          let pointIndicesBuffer = device.makeBuffer(
            bytes: &pointIndicesArray,
            length: pointIndices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
          )

          // Create segment indices buffer
          var segmentIndicesArray = segmentIndices
          let segmentIndicesBuffer = device.makeBuffer(
            bytes: &segmentIndicesArray,
            length: segmentIndices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
          )

          // Create shelter buffer
          var metalShelters = shelters
          let sheltersBuffer = device.makeBuffer(
            bytes: &metalShelters,
            length: max(1, metalShelters.count) * MemoryLayout<MetalShelter>.stride,
            options: .storageModeShared
          )

          // Create energy levels buffer
          var energyLevels = energyLevels.isEmpty ? Array(repeating: 0, count: pointIndices.count - 1) : energyLevels
          let energyLevelsBuffer = device.makeBuffer(
            bytes: &energyLevels,
            length: energyLevels.count * MemoryLayout<Int32>.stride,
            options: .storageModeShared
          )

          // Create metadata
          var metadata = OrganismMetadata(
            pointCount: UInt32(points.count),
            boundary: boundary,
            iterationCount: iterationCount,
            shelterCount: UInt32(shelters.count),
            energyGainRate: energyGainRate
          )

          let metadataBuffer = device.makeBuffer(
            bytes: &metadata,
            length: MemoryLayout<OrganismMetadata>.stride,
            options: .storageModeShared
          )

          // Create command buffer and encoder
          guard let commandBuffer = commandQueue.makeCommandBuffer(),
                let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            continuation.resume(returning: (points, energyLevels))
            return
          }

          // Set up the compute encoder
          computeEncoder.setComputePipelineState(pipelineState)
          computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
          computeEncoder.setBuffer(segmentsBuffer, offset: 0, index: 1)
          computeEncoder.setBuffer(metadataBuffer, offset: 0, index: 2)
          computeEncoder.setBuffer(pointIndicesBuffer, offset: 0, index: 3)
          computeEncoder.setBuffer(segmentIndicesBuffer, offset: 0, index: 4)
          computeEncoder.setBuffer(sheltersBuffer, offset: 0, index: 5)
          computeEncoder.setBuffer(energyLevelsBuffer, offset: 0, index: 6)

          // Calculate threadgroup size and count
          let threadsPerGrid = MTLSize(width: pointIndices.count - 1, height: 1, depth: 1)
          let maxThreadsPerThreadgroup = pipelineState.maxTotalThreadsPerThreadgroup
          let threadsPerThreadgroup = MTLSize(
            width: min(maxThreadsPerThreadgroup, threadsPerGrid.width),
            height: 1,
            depth: 1
          )

          // Dispatch the compute kernel
          computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
          computeEncoder.endEncoding()

          // Add completion handler
          commandBuffer.addCompletedHandler { _ in
            // Read results back from the buffer
            guard let pointsData = pointsBuffer?.contents(),
                  let energyLevelsData = energyLevelsBuffer?.contents() else {
              continuation.resume(returning: (points, energyLevels))
              return
            }

            let updatedPoints = UnsafeBufferPointer<SIMD2<Float>>(
              start: pointsData.assumingMemoryBound(to: SIMD2<Float>.self),
              count: points.count
            )

            let updatedEnergyLevels = UnsafeBufferPointer<Int32>(
              start: energyLevelsData.assumingMemoryBound(to: Int32.self),
              count: energyLevels.count
            )

            // Convert to Swift array
            let resultPoints = Array(updatedPoints)
            let resultEnergyLevels = Array(updatedEnergyLevels)
            continuation.resume(returning: (resultPoints, resultEnergyLevels))
          }

          // Commit command buffer
          commandBuffer.commit()
        }
    }
}

// Metal-compatible Segment structure
struct MetalSegment {
    var head: SIMD2<Float>
    var tail: SIMD2<Float>
    var cosAngle: Float
    var sinAngle: Float
    var negativeCosAngle: Float
    var negativeSinAngle: Float
    var shelterCosAngle: Float
    var shelterSinAngle: Float
    var shelterNegativeCosAngle: Float
    var shelterNegativeSinAngle: Float
}

// Metal-compatible OrganismMetadata structure
struct OrganismMetadata {
    var pointCount: UInt32
    var boundary: SIMD2<Float>
    var iterationCount: UInt32
    var shelterCount: UInt32
    var energyGainRate: Int32
}
