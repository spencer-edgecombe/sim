//
//  SimApp.swift
//  Sim
//
//  Created by Spencer Edgecombe on 1/1/25.
//

import SwiftUI
import SwiftData
/// The application entry point that configures the SwiftData container and presents the main window.
@main
struct SimApp: App {
  @State private var viewModel = EcosystemViewModel()
  @State private var isOpen = false
  @Environment(\.openWindow) var openWindow

  let container: ModelContainer
  init() {
      do {
        container = try ModelContainer(for: SavedControls.self)
      } catch {
          fatalError("Could not initialize ModelContainer: \(error)")
      }

  }

  var body: some Scene {
    WindowGroup(id: "ecosystem") {
      ContentView(viewModel: viewModel)
    }
    .modelContainer(container)
#if os(macOS)
    .defaultSize(width: 800, height: 600)
#endif
  }
}
