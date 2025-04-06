//
//  SaveControlsView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/22/25.
//

import SwiftUI
import SwiftData

struct SaveControlsView: View {
  @Environment(\.modelContext) var modelContext
  @Query private var savedControls: [SavedControls]
  @ObservedObject var viewModel: EcosystemViewModel
  @State private var saveName: String = ""
  @FocusState private var isFocused: Bool
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      VStack(spacing: 48) {
        VStack(alignment: .leading, spacing: -8) {
          TextField("Name", text: $saveName)
            .textFieldStyle(.automatic)
            .font(.title)
            .foregroundStyle(.primary)
            .overlay {
              VStack {
                Spacer()
                Rectangle()
                  .fill(isFocused ? .secondary : .tertiary)
                  .frame(height: 1)
              }
            }
            .padding(24)
          if !saveNameValid {
            Text("Name must be unique")
              .font(.caption)
              .foregroundStyle(.red)
              .padding(.horizontal, 24)
          }
        }

        HStack {
          Button("Cancel") {
            dismiss()
          }
          Button("Save") {
            modelContext.insert(SavedControls(name: saveName, controls: viewModel.controls))
            dismiss()        }
          .disabled(!saveNameValid)
        }
      }
    }
  }
  var saveNameValid: Bool {
    !savedControls.contains(where: { $0.name == saveName })
  }
}

#Preview(traits: .previewData) {
  @Previewable @StateObject var viewModel = EcosystemViewModel()
  SaveControlsView(viewModel: viewModel)
}
