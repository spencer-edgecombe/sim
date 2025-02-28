//
//  SimApp.swift
//  Sim
//
//  Created by Spencer Edgecombe on 1/1/25.
//

import SwiftUI

@main
struct SimApp: App {
  @StateObject private var viewModel = EcosystemViewModel()
  @State private var isOpen = false
  @Environment(\.openWindow) var openWindow
  
  var body: some Scene {
    WindowGroup(id: "ecosystem") {
      ContentView(viewModel: viewModel)
    }
    .defaultSize(width: 800, height: 600)
  }
}
