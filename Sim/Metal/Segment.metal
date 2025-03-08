//
//  Segment.metal
//  Sim
//
//  Created by Spencer Edgecombe on 3/1/25.
//

#include <metal_stdlib>
using namespace metal;

struct Segment {
    float2 head;
    float2 tail;

    float cosAngle;
    float sinAngle;
    float negativeCosAngle;
    float negativeSinAngle;
};

// Structure for shelter
struct Shelter {
    float2 position; // Top-left corner
    float2 size;     // Width and height
};

// Structure for organism metadata and boundary information
struct OrganismMetadata {
    uint pointCount;
    float2 boundary;
    uint iterationCount;  // Number of iterations to perform
    uint shelterCount;    // Number of shelters
};

// Check if a point is inside a shelter - optimized with early returns
bool isPointInShelter(float2 point, Shelter shelter) {
    // Early rejection tests
    if (point.x < shelter.position.x || point.y < shelter.position.y) return false;
    if (point.x > shelter.position.x + shelter.size.x) return false;
    if (point.y > shelter.position.y + shelter.size.y) return false;
    return true;
}

// Optimized rotation function to reduce duplicate code
inline float2 rotatePoint(float2 point, float2 pivot, float cosAngle, float sinAngle) {
    float2 translated = point - pivot;
    return float2(
        translated.x * cosAngle - translated.y * sinAngle,
        translated.x * sinAngle + translated.y * cosAngle
    ) + pivot;
}

kernel void rotateSegments(device Segment* segments [[buffer(0)]],
                           uint id [[thread_position_in_grid]],
                           uint totalSegments [[threads_per_grid]])
{
    if (id >= totalSegments) return;

    Segment segment = segments[id];

    // First pass rotation (right-to-left)
    segment.tail = rotatePoint(segment.tail, segment.head, segment.cosAngle, segment.sinAngle);

    // Second pass rotation (left-to-right, negative angle)
    segment.head = rotatePoint(segment.head, segment.tail, segment.negativeCosAngle, segment.negativeSinAngle);

    // Write results back
    segments[id] = segment;
}

// Kernel to handle organism movement calculations
kernel void moveOrganisms(device float2* points [[buffer(0)]],
                          device Segment* segments [[buffer(1)]],
                          device OrganismMetadata* metadata [[buffer(2)]],
                          device uint* organismIndices [[buffer(3)]],
                          device Shelter* shelters [[buffer(4)]],
                          device int* shelterCounters [[buffer(5)]],
                          uint id [[thread_position_in_grid]],
                          uint threadgroup_position [[threadgroup_position_in_grid]],
                          uint threads_per_threadgroup [[threads_per_threadgroup]])
{
    // Get organism metadata - copy instead of using a reference
    OrganismMetadata meta = *metadata;
    uint pointCount = organismIndices[id + 1] - organismIndices[id];
    uint pointStartIndex = organismIndices[id];
    uint segmentCount = pointCount - 1;
    
    // Cache shelters in threadgroup memory if there aren't too many
    threadgroup Shelter localShelters[32];
    if (threadgroup_position == 0 && meta.shelterCount <= 32) {
        for (uint s = 0; s < meta.shelterCount; s++) {
            localShelters[s] = shelters[s];
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Local cache for points to reduce global memory access
    // Use stack memory for small organisms, otherwise use global memory
    const uint MAX_LOCAL_POINTS = 64;
    float2 localPoints[MAX_LOCAL_POINTS];
    bool useLocalCache = pointCount <= MAX_LOCAL_POINTS;
    
    // Load points into local cache if possible
    if (useLocalCache) {
        for (uint i = 0; i < pointCount; i++) {
            localPoints[i] = points[pointStartIndex + i];
        }
    }
    
    // Perform multiple iterations
    for (uint iteration = 0; iteration < meta.iterationCount; iteration++) {
        // Forward pass - rotate from head to tail
        for (uint segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
            Segment segment = segments[pointStartIndex + segmentIndex];
            float2 pivotPoint = useLocalCache ? localPoints[segmentIndex] : points[pointStartIndex + segmentIndex];
            
            // Only rotate points after current segment
            for (uint pointIndex = segmentIndex + 1; pointIndex < pointCount; pointIndex++) {
                uint globalPointIndex = pointStartIndex + pointIndex;
                float2 point = useLocalCache ? localPoints[pointIndex] : points[globalPointIndex];
                
                // Perform rotation in a single step
                float2 rotated = rotatePoint(point, pivotPoint, segment.cosAngle, segment.sinAngle);
                
                // Store result
                if (useLocalCache) {
                    localPoints[pointIndex] = rotated;
                } else {
                    points[globalPointIndex] = rotated;
                }
            }
        }
        
        // Backward pass - rotate from tail to head
        for (int segmentIndex = segmentCount - 1; segmentIndex >= 0; segmentIndex--) {
            Segment segment = segments[pointStartIndex + segmentIndex];
            float2 pivotPoint = useLocalCache ? localPoints[segmentIndex + 1] : points[pointStartIndex + segmentIndex + 1];
            
            // Only rotate points before current segment
            for (uint pointIndex = 0; pointIndex <= segmentIndex; pointIndex++) {
                uint globalPointIndex = pointStartIndex + pointIndex;
                float2 point = useLocalCache ? localPoints[pointIndex] : points[globalPointIndex];
                
                // Perform rotation in a single step
                float2 rotated = rotatePoint(point, pivotPoint, segment.negativeCosAngle, segment.negativeSinAngle);
                
                // Store result
                if (useLocalCache) {
                    localPoints[pointIndex] = rotated;
                } else {
                    points[globalPointIndex] = rotated;
                }
            }
        }
        
        // Check shelter intersection on every 10th iteration or the final one
        if (iteration % 10 == 0 || iteration == meta.iterationCount - 1) {
            // Determine if organism is in any shelter
            bool isInShelter = false;
            
            // Check each point against each shelter
            for (uint i = 0; i < pointCount && !isInShelter; i++) {
                float2 point = useLocalCache ? localPoints[i] : points[pointStartIndex + i];
                
                // Use local shelter cache if available
                if (meta.shelterCount <= 32) {
                    for (uint s = 0; s < meta.shelterCount && !isInShelter; s++) {
                        isInShelter = isPointInShelter(point, localShelters[s]);
                    }
                } else {
                    for (uint s = 0; s < meta.shelterCount && !isInShelter; s++) {
                        isInShelter = isPointInShelter(point, shelters[s]);
                    }
                }
            }
            
            // Update shelter counter - use atomic operations if needed
            if (isInShelter) {
                shelterCounters[id]++;
            } else if (shelterCounters[id] > 0) {
                shelterCounters[id]--;
            }
        }
        
        // Boundary checking only on the final iteration or every 100 iterations
        if (iteration == meta.iterationCount - 1 || iteration % 100 == 0) {
            // Initialize with first point to avoid INFINITY comparisons
            float2 firstPoint = useLocalCache ? localPoints[0] : points[pointStartIndex];
            float minX = firstPoint.x;
            float minY = firstPoint.y;
            float maxX = firstPoint.x;
            float maxY = firstPoint.y;
            
            // Find min/max coordinates - start from second point
            for (uint i = 1; i < pointCount; i++) {
                float2 point = useLocalCache ? localPoints[i] : points[pointStartIndex + i];
                
                // Use SIMD min/max operations
                minX = min(minX, point.x);
                minY = min(minY, point.y);
                maxX = max(maxX, point.x);
                maxY = max(maxY, point.y);
            }
            
            // Calculate translation needed - combine conditions to reduce branches
            float2 translation = float2(0.0f);
            
            // X-axis boundary check
            if (minX < 0) {
                translation.x = -minX;
            } else if (maxX > meta.boundary.x) {
                translation.x = meta.boundary.x - maxX;
            }
            
            // Y-axis boundary check
            if (minY < 0) {
                translation.y = -minY;
            } else if (maxY > meta.boundary.y) {
                translation.y = meta.boundary.y - maxY;
            }
            
            // Apply translation if needed - use vector operations
            if (translation.x != 0 || translation.y != 0) {
                for (uint i = 0; i < pointCount; i++) {
                    if (useLocalCache) {
                        localPoints[i] += translation;
                    } else {
                        points[pointStartIndex + i] += translation;
                    }
                }
            }
        }
    }
    
    // Write back local cache to global memory if used
    if (useLocalCache) {
        for (uint i = 0; i < pointCount; i++) {
            points[pointStartIndex + i] = localPoints[i];
        }
    }
}
