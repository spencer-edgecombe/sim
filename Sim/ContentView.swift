//
//  ContentView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 1/1/25.
//

import SwiftUI
import Combine

/// The main view of the application that displays the ecosystem and its controls
struct ContentView: View {
  // MARK: - State Objects

  @ObservedObject private var viewModel = EcosystemViewModel()

  init(viewModel: EcosystemViewModel) {
    self.viewModel = viewModel
  }
  // MARK: - State
  
  
  // MARK: - Body
  
  var body: some View {
    NavigationSplitView {
      ControlView(viewModel: viewModel)
        .navigationSplitViewColumnWidth(min: 200, ideal: 400)
    } detail: {
      canvasView
    }
  }
  
  private var canvasView: some View {
      TimelineView(.animation(minimumInterval: 1 / viewModel.refreshRate)) { _ in
        let path = viewModel.path
        return Canvas(rendersAsynchronously: false) { context, size in
          context.stroke(path, with: .foreground)
        }
        .drawingGroup()
        .frame(width: Constants.boundary.width, height: Constants.boundary.height)
      }
  }
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
    .task {
      viewModel.togglePlayback()
    }
}
