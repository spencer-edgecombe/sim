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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var sheetHeight: PresentationDetent = .medium

  init(viewModel: EcosystemViewModel) {
    self.viewModel = viewModel
  }
  // MARK: - State

  @State var rect: CGRect?
  @State var showDetails: Bool = true
  @State var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

  // MARK: - Body
  
  var body: some View {
    if horizontalSizeClass == .compact {
      // iPhone layout
      ZStack {
        canvasView
        if !showDetails {
          VStack {
            Spacer()
            HStack {
              Spacer()
              Button(action: {
                showDetails.toggle()
              }) {
                Image(systemName: "inset.filled.bottomhalf.rectangle.portrait")
                  .foregroundStyle(.primary)
                  .font(.title)
                  .padding()
                  .background(Circle().fill(.primary.quinary))
              }
              .padding()
            }
          }
        }

        
        // Empty view to anchor sheet presentation
        Color.clear
          .sheet(isPresented: $showDetails) {
            ControlView(viewModel: viewModel)
              .presentationDetents([.fraction(1/8), .medium, .large], selection: $sheetHeight)
              .presentationDragIndicator(.visible)
              .interactiveDismissDisabled()
              .presentationBackgroundInteraction(.enabled(upThrough: .large))
          }
      }

    } else {
      // iPad/Mac layout (existing NavigationSplitView)
      NavigationSplitView(columnVisibility: $columnVisibility) {
        ControlView(viewModel: viewModel)
          .navigationSplitViewColumnWidth(300)
      } detail: {
        canvasView      .navigationSplitViewStyle(.prominentDetail)

      }
    }
  }
  
  private var canvasView: some View {
    TimelineView(.animation(minimumInterval: 1 / Double(viewModel.controls.refreshRate))) { _ in
        Canvas(rendersAsynchronously: false) { context, size in
          context.stroke(viewModel.boundaryPath, with: .color(.black))
          // Draw shelters with blue fill and stroke
          context.fill(viewModel.shelterPath, with: .color(.green.opacity(0.2)))

          context.stroke(viewModel.path, with: .foreground)

          // Draw organism shelter counters near each organism
          // Only draw counters if we have the same number of counters as organisms
        }
        .frame(width: viewModel.boundary.width, height: viewModel.boundary.height)
      }
  }
}

// MARK: - Preview

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
