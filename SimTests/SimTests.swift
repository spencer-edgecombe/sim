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

  var ecosystem = Ecosystem.shared
  var cancellables = Set<AnyCancellable>()

  @Ecosystem
  func testPerformance() async {
    await ecosystem.addRandomOrganism(length: 10, movementLimit: 0.01, count: 100)
    
    let exp = expectation(description: "")
    Task { @MainActor [weak self, exp] in
      guard let self else { return }
      await self.ecosystem.startMoving(frameRate: 0, chunkSize: 1) { _ in
        exp.fulfill()
      }
    }
    await MainActor.run { [weak self, exp] in
      self?.measure {
        self?.wait(for: [exp])
      }
    }

  }

}
