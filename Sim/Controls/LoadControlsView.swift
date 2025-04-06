//
//  LoadControlsView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/22/25.
//

import SwiftUI
import SwiftData

struct LoadControlsView: View {
  @Environment(\.modelContext) var modelContext
  @Query private var savedControls: [SavedControls]
  @State private var selectedControl: SavedControls?
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var viewModel: EcosystemViewModel
  var body: some View {
    NavigationStack {
    List(selection: $selectedControl) {
      ForEach(savedControls) { saved in
        Text(saved.name)
        .tag(saved)
      }
    }
    .frame(minHeight: 300)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button("Load") {
          guard let controls = selectedControl?.controls else { return }
          viewModel.controls = controls
          viewModel.reset()
          dismiss()
        }
        .disabled(selectedControl == nil)
      }
      ToolbarItem(placement: .automatic) {
        Button("Cancel") {
          dismiss()
        }
      }
    }
    }
  }
}

#Preview(traits: .previewData) {
  @Previewable @StateObject var viewModel = EcosystemViewModel()
  LoadControlsView(viewModel: viewModel)
}
