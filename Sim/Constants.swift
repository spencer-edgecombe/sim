//
//  Constants.swift
//  Sim
//
//  Created by Spencer Edgecombe on 4/15/25.
//

import Foundation
import simd
import SwiftUI

/// Global constants used throughout the application
enum Constants {
  /// The boundary size of the simulation
  #if os(iOS)
  static let boundarySIMD2 = UIDevice.current.userInterfaceIdiom == .phone ?
  SIMD2<Float>(x: Float(UIScreen.main.bounds.width - 16), y: Float(UIScreen.main.bounds.height - 300)) :
  SIMD2<Float>(x: 300, y: 550)
  #else
  static let boundarySIMD2 = SIMD2<Float>(x: 800, y: 600)
  #endif
}
