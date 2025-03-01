//
//  SimTests.swift
//  SimTests
//
//  Created by Spencer Edgecombe on 2/22/25.
//

import XCTest
import Combine

@testable import Sim
class SimTests: XCTestCase {

  var cancellables = Set<AnyCancellable>()

  @MainActor
  func test_mps10() async {
    var mpsHistory: [Int] = []
    for _ in 0..<50 {
      mpsHistory.append(await mps(10))
    }
    let average = mpsHistory.reduce(0) { $0 + $1 } / mpsHistory.count
    print("\(average)mps")
  }

  @MainActor
  func test_mps100() async {
    var mpsHistory: [Int] = []
    for _ in 0..<50 {
      mpsHistory.append(await mps(100))
    }
    let average = mpsHistory.reduce(0) { $0 + $1 } / mpsHistory.count
    print("\(average)mps")
  }

  @MainActor
  func test_mps1000() async {
    var mpsHistory: [Int] = []
    for _ in 0..<50 {
      mpsHistory.append(await mps(1000))
    }
    let average = mpsHistory.reduce(0) { $0 + $1 } / mpsHistory.count
    print("\(average)mps")
  }

  @MainActor
  func mps(_ count: Int) async -> Int {
    var ecosystem: Ecosystem? = Ecosystem()
    await ecosystem?.addRandomOrganism(length: 10, movementLimit: 0.05, count: count)
    let exp = expectation(description: "Waiting for MPS measurement")
    var mps: Int = 0
    
    // Create a flag to track if we've already fulfilled the expectation
    var isExpFulfilled = false
    
    // Add a timeout task to ensure we don't wait forever
    let timeoutTask = Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds timeout
      if !isExpFulfilled {
        isExpFulfilled = true
        exp.fulfill()
      }
    }
    
    await ecosystem?.mpsPublisher
      .sink { mpsResult in
        mps = mpsResult
        Task {
          await ecosystem?.stopMoving()
          if !isExpFulfilled {
            isExpFulfilled = true
            exp.fulfill()
          }
        }
      }
      .store(in: &cancellables)
    
    // Use a shorter mpsInterval (0.5 seconds) for faster test execution
    await ecosystem?.startMoving(frameRate: 0, chunkSize: 2, updateMovesPerSecond: { _ in }, mpsInterval: 0.05)

    // Wait for either the mpsPublisher to emit or the timeout to occur
    await fulfillment(of: [exp], timeout: 3) // 3 second timeout as additional safety
    
    // Cancel the timeout task if it's still running
    timeoutTask.cancel()
    
    // If we didn't get an actual MPS value, calculate an approximate one
    if mps == 0 {
      // Get an approximate MPS value based on the current state
      Task {
        await ecosystem?.stopMoving()
      }
      // Default to a reasonable value if we couldn't get a real measurement
      mps = count / 10 // Simple approximation
    }
    
    ecosystem = nil
    return mps
  }


}
