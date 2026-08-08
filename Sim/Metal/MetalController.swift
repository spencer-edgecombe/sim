//
//  MetalController.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/1/25.
//

import Metal
import MetalKit
import Foundation

/// Manages the Metal device, command queue, and compute pipeline used to run organism movement on the GPU.
///
/// Access the singleton via ``shared``. The controller converts Swift-side organism data into
/// Metal buffers, dispatches the `moveOrganisms` compute kernel, and returns the updated
/// positions and energy levels.
///
/// Internally maintains two "buffer sets" so the CPU can populate buffers and encode the
/// next dispatch while the GPU is still processing the previous one. A `DispatchSemaphore`
/// caps the number of in-flight dispatches at ``Self/inFlightCount``.
class MetalController {
  /// The shared singleton instance.
  static let shared: MetalController = MetalController()!
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    // Compute pipeline state for organism movement
    private var moveOrganismsPipelineState: MTLComputePipelineState?

    /// Maximum number of dispatches that can be in flight simultaneously.
    /// Two is the minimum that yields CPU/GPU overlap (one set being filled
    /// by the CPU while the GPU drains the other).
    private static let inFlightCount: Int = 2

    /// One full collection of buffers used by a single dispatch. Holding
    /// two of these lets the CPU memcpy + encode for frame N+1 in parallel
    /// with the GPU executing frame N.
    private final class BufferSet {
        var pointsBuffer: MTLBuffer?
        var pointsCapacity: Int = 0
        var segmentsBuffer: MTLBuffer?
        var segmentsCapacity: Int = 0
        var pointIndicesBuffer: MTLBuffer?
        var pointIndicesCapacity: Int = 0
        var segmentIndicesBuffer: MTLBuffer?
        var segmentIndicesCapacity: Int = 0
        var sheltersBuffer: MTLBuffer?
        var sheltersCapacity: Int = 0
        var energyLevelsBuffer: MTLBuffer?
        var energyLevelsCapacity: Int = 0
        var metadataBuffer: MTLBuffer?
    }

    /// The pool of buffer sets, one per allowed in-flight dispatch.
    private var bufferSets: [BufferSet]

    /// Index of the next buffer set the CPU will write into. Advances on
    /// every `enqueueMoveOrganisms` call. Only mutated on the serial
    /// dispatch queue / by the calling actor, so does not need its own
    /// synchronization.
    private var nextBufferSetIndex: Int = 0

    /// Caps in-flight dispatches at ``Self/inFlightCount``. The CPU
    /// `wait()`s before grabbing a buffer set; each completion handler
    /// `signal()`s, freeing that set for reuse.
    private let inFlightSemaphore: DispatchSemaphore

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }

        self.device = device
        self.commandQueue = queue
        self.library = library
        self.bufferSets = (0..<Self.inFlightCount).map { _ in BufferSet() }
        self.inFlightSemaphore = DispatchSemaphore(value: Self.inFlightCount)
        
        // Create the compute pipeline for organism movement
        if let moveOrganismsFunction = library.makeFunction(name: "moveOrganisms") {
            do {
                moveOrganismsPipelineState = try device.makeComputePipelineState(function: moveOrganismsFunction)
            } catch {
                print("Error creating move organisms compute pipeline: \(error)")
            }
        }
    }

    private func updateBuffer<T>(_ buffer: inout MTLBuffer?, capacity: inout Int, data: [T]) {
        let count = max(data.count, 1)
        let stride = MemoryLayout<T>.stride
        if count > capacity || buffer == nil {
            buffer = device.makeBuffer(length: count * stride, options: .storageModeShared)
            capacity = count
        }
        if let contents = buffer?.contents(), !data.isEmpty {
            data.withUnsafeBytes { rawBuffer in
                contents.copyMemory(from: rawBuffer.baseAddress!, byteCount: data.count * stride)
            }
        }
    }
    
    /// Submits a `moveOrganisms` dispatch to the GPU and returns a task that
    /// resolves once the GPU has produced its updated positions and energy levels.
    ///
    /// Unlike ``moveOrganisms(points:segments:pointIndices:segmentIndices:boundary:shelters:energyLevels:iterationCount:energyGainRate:)``,
    /// this method returns synchronously after the command buffer has been
    /// committed -- the caller can do other work (including enqueuing the
    /// next dispatch into a different buffer set) while the GPU executes.
    ///
    /// Up to ``Self/inFlightCount`` dispatches can be in flight at once;
    /// additional callers block on the in-flight semaphore until a buffer
    /// set frees up.
    ///
    /// - Parameters: same as ``moveOrganisms(...)``.
    /// - Returns: A task whose value is `(updatedPoints, updatedEnergyLevels)`.
    ///   When the dispatch is rejected (no pipeline, empty inputs, or command
    ///   buffer creation failed), the task resolves to the unchanged inputs.
    func enqueueMoveOrganisms(
        points: [SIMD2<Float>],
        segments: [Segment],
        pointIndices: [UInt32],
        segmentIndices: [UInt32],
        boundary: SIMD2<Float>,
        shelters: [MetalShelter] = [],
        energyLevels: [Int32] = [],
        iterationCount: UInt32 = 1,
        energyGainRate: Int32 = 1
    ) -> Task<([SIMD2<Float>], [Int32]), Never> {
        guard let pipelineState = moveOrganismsPipelineState,
              !points.isEmpty,
              !segments.isEmpty,
              pointIndices.count > 1,
              segmentIndices.count > 1 else {
            return Task { (points, energyLevels) }
        }

        // Wait for an open slot; reserved by this dispatch until its
        // completion handler runs and signals the semaphore.
        inFlightSemaphore.wait()

        let bufferSet = bufferSets[nextBufferSetIndex]
        nextBufferSetIndex = (nextBufferSetIndex + 1) % bufferSets.count

        updateBuffer(&bufferSet.pointsBuffer, capacity: &bufferSet.pointsCapacity, data: points)
        updateBuffer(&bufferSet.segmentsBuffer, capacity: &bufferSet.segmentsCapacity, data: segments)
        updateBuffer(&bufferSet.pointIndicesBuffer, capacity: &bufferSet.pointIndicesCapacity, data: pointIndices)
        updateBuffer(&bufferSet.segmentIndicesBuffer, capacity: &bufferSet.segmentIndicesCapacity, data: segmentIndices)
        updateBuffer(&bufferSet.sheltersBuffer, capacity: &bufferSet.sheltersCapacity, data: shelters)

        let energyLevels = energyLevels.isEmpty
            ? Array(repeating: Int32(0), count: pointIndices.count - 1)
            : energyLevels
        updateBuffer(&bufferSet.energyLevelsBuffer, capacity: &bufferSet.energyLevelsCapacity, data: energyLevels)

        var metadata = OrganismMetadata(
            pointCount: UInt32(points.count),
            boundary: boundary,
            iterationCount: iterationCount,
            shelterCount: UInt32(shelters.count),
            energyGainRate: energyGainRate
        )
        if bufferSet.metadataBuffer == nil {
            bufferSet.metadataBuffer = device.makeBuffer(
                length: MemoryLayout<OrganismMetadata>.stride,
                options: .storageModeShared
            )
        }
        bufferSet.metadataBuffer?.contents().copyMemory(
            from: &metadata,
            byteCount: MemoryLayout<OrganismMetadata>.stride
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            // Release the slot we reserved before bailing out.
            inFlightSemaphore.signal()
            return Task { (points, energyLevels) }
        }

        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(bufferSet.pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(bufferSet.segmentsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(bufferSet.metadataBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(bufferSet.pointIndicesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(bufferSet.segmentIndicesBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(bufferSet.sheltersBuffer, offset: 0, index: 5)
        computeEncoder.setBuffer(bufferSet.energyLevelsBuffer, offset: 0, index: 6)

        let threadsPerGrid = MTLSize(width: pointIndices.count - 1, height: 1, depth: 1)
        let maxThreadsPerThreadgroup = pipelineState.maxTotalThreadsPerThreadgroup
        let threadsPerThreadgroup = MTLSize(
            width: min(maxThreadsPerThreadgroup, threadsPerGrid.width),
            height: 1,
            depth: 1
        )

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        // Capture buffer references so the closures below don't depend on
        // mutable state of `self`.
        let resultPointsBuffer = bufferSet.pointsBuffer
        let resultEnergyBuffer = bufferSet.energyLevelsBuffer
        let pointCount = points.count
        let energyCount = energyLevels.count
        let semaphore = inFlightSemaphore

        // Bridge GPU completion to a one-shot async stream so the caller
        // can `await` it later. We finish the stream inside the Metal
        // completion handler; whoever first iterates the stream gets the
        // result. The stream must be set up *before* commit, since the GPU
        // can finish (and call back) in the time between this line and the
        // task closure even attempting to read it.
        let (stream, continuation) = AsyncStream<([SIMD2<Float>], [Int32])>.makeStream()
        commandBuffer.addCompletedHandler { _ in
            defer { semaphore.signal() }

            let result: ([SIMD2<Float>], [Int32])
            if let pointsData = resultPointsBuffer?.contents(),
               let energyLevelsData = resultEnergyBuffer?.contents() {
                let updatedPoints = UnsafeBufferPointer<SIMD2<Float>>(
                    start: pointsData.assumingMemoryBound(to: SIMD2<Float>.self),
                    count: pointCount
                )
                let updatedEnergyLevels = UnsafeBufferPointer<Int32>(
                    start: energyLevelsData.assumingMemoryBound(to: Int32.self),
                    count: energyCount
                )
                result = (Array(updatedPoints), Array(updatedEnergyLevels))
            } else {
                result = (points, energyLevels)
            }
            continuation.yield(result)
            continuation.finish()
        }

        // Commit *now* so the GPU starts work immediately and the caller
        // gets CPU/GPU overlap (this is the whole point of the double-
        // buffered pipeline). The returned task only does the wait.
        commandBuffer.commit()

        return Task {
            for await result in stream {
                return result
            }
            // Stream finished without yielding (shouldn't happen because
            // the completion handler always yields exactly once, but
            // satisfies the type system).
            return (points, energyLevels)
        }
    }

    /// Dispatches the Metal compute kernel to move all organisms in a single GPU pass.
    ///
    /// - Parameters:
    ///   - points: Flat array of all organism joint positions.
    ///   - segments: Flat array of all organism segments.
    ///   - pointIndices: Prefix-sum indices marking the start of each organism's points in `points`.
    ///   - segmentIndices: Prefix-sum indices marking the start of each organism's segments in `segments`.
    ///   - boundary: Simulation boundary dimensions for edge clamping.
    ///   - shelters: Current shelters used for energy calculations.
    ///   - energyLevels: Per-organism energy values to be updated on the GPU.
    ///   - iterationCount: Number of movement iterations to run per dispatch.
    ///   - energyGainRate: Energy gained per iteration while inside a shelter.
    /// - Returns: A tuple of updated point positions and updated energy levels.
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
        let task = enqueueMoveOrganisms(
            points: points,
            segments: segments,
            pointIndices: pointIndices,
            segmentIndices: segmentIndices,
            boundary: boundary,
            shelters: shelters,
            energyLevels: energyLevels,
            iterationCount: iterationCount,
            energyGainRate: energyGainRate
        )
        return await task.value
    }
}
