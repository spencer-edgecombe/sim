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
  
  float shelterCosAngle;
  float shelterSinAngle;
  float shelterNegativeCosAngle;
  float shelterNegativeSinAngle;
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
  int32_t energyGainRate; // Rate at which energy increases in shelters
};

// Check if a point is inside a shelter
bool isPointInShelter(float2 point, Shelter shelter) {
  return (point.x >= shelter.position.x &&
          point.x <= shelter.position.x + shelter.size.x &&
          point.y >= shelter.position.y &&
          point.y <= shelter.position.y + shelter.size.y);
}

// Kernel to handle organism movement calculations
kernel void moveOrganisms(device float2* points [[buffer(0)]],
                          device Segment* segments [[buffer(1)]],
                          device OrganismMetadata* metadata [[buffer(2)]],
                          device uint* pointIndices [[buffer(3)]],
                          device uint* segmentIndices [[buffer(4)]],
                          device Shelter* shelters [[buffer(5)]],
                          device int* energyLevels [[buffer(6)]],
                          uint id [[thread_position_in_grid]])
{
  // Get organism metadata
  OrganismMetadata meta = *metadata;
  uint pointCount = pointIndices[id + 1] - pointIndices[id];
  
  uint segmentStartIndex = segmentIndices[id];
  uint segmentEndIndex = segmentIndices[id + 1];
  uint segmentCount = segmentEndIndex - segmentStartIndex;

  // Determine if organism is in any shelter at the start
  bool isInShelter = false;
  for (uint i = 0; i < pointCount; i++) {
    float2 point = points[pointIndices[id] + i];
    
    for (uint s = 0; s < meta.shelterCount; s++) {
      if (isPointInShelter(point, shelters[s])) {
        isInShelter = true;
        break;
      }
    }
    
    if (isInShelter) break;
  }

  // Perform multiple iterations
  for (uint iteration = 0; iteration < meta.iterationCount; iteration++) {
    // Forward pass - rotate from head to tail
    for (uint i = 0; i < segmentCount; i++) {
      uint globalSegmentIndex = segmentStartIndex + i;
      Segment segment = segments[globalSegmentIndex];
      
      float cos_angle = isInShelter ? segment.shelterCosAngle : segment.cosAngle;
      float sin_angle = isInShelter ? segment.shelterSinAngle : segment.sinAngle;

      // Only rotate points after current segment
      for (uint j = i + 1; j < pointCount; j++) {
        // Translate to origin
        float2 translated = points[pointIndices[id] + j] - points[pointIndices[id] + i];

        // Translate back
        points[pointIndices[id] + j] = float2(
          translated.x * cos_angle - translated.y * sin_angle,
          translated.x * sin_angle + translated.y * cos_angle
        ) + points[pointIndices[id] + i];
      }
    }

    // Backward pass - rotate from tail to head
    for (int i = segmentCount - 1; i >= 0; i--) {
      uint globalSegmentIndex = segmentStartIndex + i;
      Segment segment = segments[globalSegmentIndex];
      
      float negative_cos_angle = isInShelter ? segment.shelterNegativeCosAngle : segment.negativeCosAngle;
      float negative_sin_angle = isInShelter ? segment.shelterNegativeSinAngle : segment.negativeSinAngle;

      // Only rotate points before current segment
      for (int j = 0; j <= i; j++) {
        // Translate to origin
        float2 translated = points[pointIndices[id] + j] - points[pointIndices[id] + i + 1];

        // Translate back
        points[pointIndices[id] + j] = float2(
          translated.x * negative_cos_angle - translated.y * negative_sin_angle,
          translated.x * negative_sin_angle + translated.y * negative_cos_angle
        ) + points[pointIndices[id] + i + 1];
      }
    }

    // Check shelter intersection on every 10th iteration or the final one
    if (iteration % 10 == 0 || iteration == meta.iterationCount - 1) {
      // Determine if organism is in any shelter
      bool isInShelter = false;

      // Check each point against each shelter
      for (uint i = 0; i < pointCount; i++) {
        float2 point = points[pointIndices[id] + i];

        for (uint s = 0; s < meta.shelterCount; s++) {
          if (isPointInShelter(point, shelters[s])) {
            isInShelter = true;
            break;
          }
        }

        if (isInShelter) break;
      }

      // Update energy level
      if (isInShelter) {
        energyLevels[id] += meta.energyGainRate;
      } else if (energyLevels[id] > 0) {
        // Always decrease by at least 1 when outside shelter
        energyLevels[id] = max(0, energyLevels[id] - 1);
      }
    }

    // Boundary checking only on the final iteration or every 100 iterations
    if (iteration == meta.iterationCount - 1 || iteration % 100 == 0) {
      float minX = INFINITY;
      float minY = INFINITY;
      float maxX = -INFINITY;
      float maxY = -INFINITY;

      // Find min/max coordinates
      for (uint i = 0; i < pointCount; i++) {
        float2 point = points[pointIndices[id] + i];

        minX = min(minX, point.x);
        minY = min(minY, point.y);
        maxX = max(maxX, point.x);
        maxY = max(maxY, point.y);
      }

      // Calculate translation needed
      float dx = 0.0f;
      float dy = 0.0f;

      if (minX < 0) {
        dx = -minX;
      } else if (maxX > meta.boundary.x) {
        dx = meta.boundary.x - maxX;
      }

      if (minY < 0) {
        dy = -minY;
      } else if (maxY > meta.boundary.y) {
        dy = meta.boundary.y - maxY;
      }

      // Apply translation if needed
      if (dx != 0 || dy != 0) {
        for (uint i = 0; i < pointCount; i++) {
          points[pointIndices[id] + i].x += dx;
          points[pointIndices[id] + i].y += dy;
        }
      }
    }
  }
}
