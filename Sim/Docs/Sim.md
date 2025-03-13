# Sim Technical Documentation

## Organism Movement Data Flow

### Data Structures

#### Core Types
- **Organism**: Collection of connected segments forming a flexible chain
- **Segment**: Basic unit with head and tail points, plus pre-calculated trigonometric values for rotation
- **Shelter**: Rectangular area defined by position and size where organisms can accumulate counter values

#### Metal-Compatible Types
- **MetalSegment**: Optimized version of Segment for GPU computation
- **MetalShelter**: Simplified shelter representation for GPU computation
- **OrganismMetadata**: Configuration data for GPU computation including boundaries and iteration counts

### Movement Iteration Flow

1. **Ecosystem Layer** (`Ecosystem.swift`)
   - Maintains master state of organisms and shelters
   - Initiates movement through `startMoving()` or `step()`
   - Prepares data for Metal processing:
     - Flattens organism points into continuous array
     - Creates organism boundary indices
     - Converts shelters to Metal format
     - Tracks shelter counters per organism

2. **ViewModel Layer** (`EcosystemViewModel.swift`)
   - Controls simulation parameters (frame rate, iteration count, etc.)
   - Manages UI state and updates
   - Subscribes to point updates and shelter counter changes
   - Converts simulation data to SwiftUI paths for rendering

3. **Metal Controller** (`MetalController.swift`)
   - Bridges between Swift and Metal shader code
   - Handles buffer creation and management
   - Coordinates compute pipeline execution
   - Processes data in batches for efficiency

4. **Metal Shader** (`Segment.metal`)
   - Performs parallel computation of organism movement
   - Executes multiple iterations per frame
   - Handles collision detection with boundaries
   - Updates shelter counters based on organism positions

### Data Flow for One Movement Frame

1. **Preparation**
   ```swift
   // Ecosystem prepares data
   var allPoints: [SIMD2<Float>] = []
   var allSegments: [Segment] = []
   var organismIndices: [UInt32] = [0]
   
   // Collect data from all organisms
   for organism in organisms {
     allPoints.append(contentsOf: organism.points)
     allSegments.append(contentsOf: organism.segments)
     organismIndices.append(UInt32(allPoints.count))
   }
   ```

2. **Metal Processing**
   ```swift
   // MetalController processes movement
   metalController.moveOrganisms(
     points: allPoints,
     segments: allSegments,
     organismIndices: organismIndices,
     boundary: Constants.boundarySIMD2,
     shelters: metalShelters,
     shelterCounters: shelterCounters,
     iterationCount: metalIterationCount
   )
   ```

3. **Result Distribution**
   - Updated points are sent back to Ecosystem
   - Ecosystem updates organism positions
   - Shelter counters are updated
   - ViewModel receives updates through publishers
   - UI is refreshed with new positions

### Performance Optimizations

1. **Batch Processing**
   - Multiple iterations per Metal dispatch
   - Shared memory usage for frequent calculations
   - Pre-calculated trigonometric values

2. **Memory Management**
   - Reusable buffers for Metal computations
   - Efficient data structures for GPU processing
   - Minimal data copying between CPU and GPU

3. **Update Scheduling**
   - Shelter checks every 10 iterations
   - Boundary checks every 100 iterations
   - Configurable frame rate and iteration count

### Key Considerations

1. **Thread Safety**
   - Ecosystem is an actor to ensure thread-safe access
   - Metal operations are asynchronous
   - Publishers manage state updates across threads

2. **Memory Layout**
   - Continuous arrays for GPU efficiency
   - Organism boundaries tracked through indices
   - Shelter data simplified for Metal processing

3. **State Management**
   - Clear ownership of master state in Ecosystem
   - ViewModel handles derived state for UI
   - Metal controller manages temporary computation state
