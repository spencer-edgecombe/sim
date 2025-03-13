kernel void moveOrganisms(device float2* points [[buffer(0)]],
                          device Segment* segments [[buffer(1)]],
                          device OrganismMetadata* metadata [[buffer(2)]],
                          device uint* organismIndices [[buffer(3)]],
                          device Shelter* shelters [[buffer(4)]],
                          device int* energyLevels [[buffer(5)]],
                          uint id [[thread_position_in_grid]])
{
  // Skip movement if organism has no energy
  if (energyLevels[id] <= 0) {
    return;
  }

  // Get organism metadata
  // ... existing code ...
} 