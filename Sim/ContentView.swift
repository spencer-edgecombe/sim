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
        .navigationSplitViewColumnWidth(250)
    } detail: {
      canvasView
    }
  }
  
  private var canvasView: some View {
      TimelineView(.animation(minimumInterval: 1 / viewModel.refreshRate)) { _ in
        Canvas(rendersAsynchronously: false) { context, size in
          context.stroke(viewModel.boundaryPath, with: .color(.black))
          // Draw shelters with blue fill and stroke
          
            let path = viewModel.path
            let shelterPath = viewModel.shelterPath
//            let shelterCounters = viewModel.shelterCounters
//            let organismCenters = viewModel.organismCenters
          context.fill(shelterPath, with: .color(.green.opacity(0.2)))
          
          // Draw organisms
          context.stroke(path, with: .foreground)

          // Draw organism shelter counters near each organism
          // Only draw counters if we have the same number of counters as organisms
//          if shelterCounters.count == organismCenters.count {
//            for (index, center) in organismCenters.enumerated() {
//              let counterValue = shelterCounters[index]
//              
//              // Only draw counter if it's greater than 0
//              if counterValue > 0 {
//                let font = Font.system(size: 14).weight(.bold)
//                let text = Text("\(index) - \(counterValue)")
//                  .font(font)
//                  .foregroundColor(.green)
//
//                // Position the counter text slightly offset from the organism center
//                let textPoint = CGPoint(x: center.x + 10, y: center.y - 10)
//                context.draw(text, at: textPoint)
//              }
//            }
//            
//          }
            context.stroke(viewModel.wipOrganismPath, with: .color(.red))
        }
        .drawingGroup()
        .frame(width: Constants.boundarySIMD2.size.width, height: Constants.boundarySIMD2.size.height)
      }
  }
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
