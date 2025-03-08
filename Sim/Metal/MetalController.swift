//
//  MetalController.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/1/25.
//

import Metal
import MetalKit

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
        organismIndices: [UInt32],
        boundary: SIMD2<Float>,
        shelters: [MetalShelter] = [],
        shelterCounters: [Int] = [],
        iterationCount: UInt32 = 1,
        completion: @escaping ([SIMD2<Float>], [Int]) -> Void
    ) {
        guard let pipelineState = moveOrganismsPipelineState,
              !points.isEmpty,
              !segments.isEmpty,
              organismIndices.count > 1 else {
            completion(points, shelterCounters)
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
                negativeSinAngle: segment.negativeSinAngle
            )
        }
        
        let segmentsBuffer = device.makeBuffer(
            bytes: &metalSegments,
            length: metalSegments.count * MemoryLayout<MetalSegment>.stride,
            options: .storageModeShared
        )
        
        // Create shelter buffer
        var metalShelters = shelters
        let sheltersBuffer = device.makeBuffer(
            bytes: &metalShelters,
            length: max(1, metalShelters.count) * MemoryLayout<MetalShelter>.stride,
            options: .storageModeShared
        )
        
        // Create shelter counters buffer
        var counters = shelterCounters.isEmpty ? Array(repeating: 0, count: organismIndices.count - 1) : shelterCounters
        let countersBuffer = device.makeBuffer(
            bytes: &counters,
            length: counters.count * MemoryLayout<Int>.stride,
            options: .storageModeShared
        )
        
        // Create metadata
        var metadata = OrganismMetadata(
            pointCount: UInt32(points.count),
            boundary: boundary,
            iterationCount: iterationCount,
            shelterCount: UInt32(shelters.count)
        )
        
        let metadataBuffer = device.makeBuffer(
            bytes: &metadata,
            length: MemoryLayout<OrganismMetadata>.stride,
            options: .storageModeShared
        )
        
        // Create organism indices buffer
        var indices = organismIndices
        let indicesBuffer = device.makeBuffer(
            bytes: &indices,
            length: indices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            completion(points, shelterCounters)
            return
        }
        
        // Set up the compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(segmentsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(metadataBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(indicesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(sheltersBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(countersBuffer, offset: 0, index: 5)
        
        // Calculate threadgroup size and count
        let threadsPerGrid = MTLSize(width: organismIndices.count - 1, height: 1, depth: 1)
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
                  let countersData = countersBuffer?.contents() else {
                completion(points, shelterCounters)
                return
            }
            
            let updatedPoints = UnsafeBufferPointer<SIMD2<Float>>(
                start: pointsData.assumingMemoryBound(to: SIMD2<Float>.self),
                count: points.count
            )
            
            let updatedCounters = UnsafeBufferPointer<Int>(
                start: countersData.assumingMemoryBound(to: Int.self),
                count: counters.count
            )
            
            // Convert to Swift array
            let resultPoints = Array(updatedPoints)
            let resultCounters = Array(updatedCounters)
            completion(resultPoints, resultCounters)
        }
        
        // Commit command buffer
        commandBuffer.commit()
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
}

// Metal-compatible OrganismMetadata structure
struct OrganismMetadata {
    var pointCount: UInt32
    var boundary: SIMD2<Float>
    var iterationCount: UInt32
    var shelterCount: UInt32
}
