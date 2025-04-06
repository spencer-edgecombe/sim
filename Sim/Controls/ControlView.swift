//
//  ControlView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI
import Combine
import SwiftData

struct ControlView: View {

  @State var ids: [SimID] = []
  @State var cancellables = Set<AnyCancellable>()
  @ObservedObject var viewModel: EcosystemViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var showSaveControls = false
  @State private var showLoadControls = false

  var body: some View {
    NavigationView {
      List {
        Section {
          Group {
            VStack(alignment: .leading) {
              Text(viewModel.movesPerSecond.description + " mps")
              Text(ids.count.description + " organisms")
            }
            HStack {
              Button("save", systemImage: "tray.and.arrow.down.fill") {
                showSaveControls = true
              }
              Button("load", systemImage: "tray.and.arrow.up.fill") {
                showLoadControls = true
              }
              Spacer()
            }
          }
          .buttonStyle(SquareButtonStyle())
          .fontWeight(.light)
          .labelStyle(.iconOnly)
          .font(.largeTitle)
          .listRowBackground(Color.clear)
          .listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
          .listRowSeparator(.hidden)
        }
        Section {
          controlsSection
            .listRowSeparator(.hidden, edges: .all)
        }
      }
      .scrollClipDisabled()
      .scrollContentBackground(.hidden)
      .background(Material.thick)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("close", systemImage: "chevron.down") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigation) {
          Button(
            viewModel.isPlaying ? "pause" : "play", 
            systemImage: viewModel.isPlaying ? "pause" : "play"
          ) {
            Task {
              await viewModel.togglePlayback()
            }
          }
        }
        ToolbarItem(placement: .navigation) {
          Button("step", systemImage: "forward") {
            viewModel.step()
          }
        }
        ToolbarItem(placement: .navigation) {
          Button("reset", systemImage: "arrow.counterclockwise") {
            viewModel.reset()
          }
        }
        
      }
      .task {
        await Ecosystem.shared.statePublisher
          .map(\.organismIDs)
          .sink { ids in
            Task { @MainActor in
              self.ids = ids
            }
          }
          .store(in: &cancellables)
      }
      .buttonStyle(ControlButtonStyle())
    }
    .sheet(isPresented: $showSaveControls) {
      SaveControlsView(viewModel: viewModel)
    }
    .sheet(isPresented: $showLoadControls) {
      LoadControlsView(viewModel: viewModel)
    }
    .tint(.indigo)
  }


  // MARK: - View Components

  private var controlsSection: some View {
    Group {
      ControlPicker(
        title: "Organism Count",
        selectedOption: .init(get: {
          viewModel.controls.organismCount
        }, set: { newValue in
          viewModel.controls.organismCount = newValue
        }),
        options: [1, 10, 100, 1000, 10000, 100000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵"]
      )
      ControlPicker(
        title: "Min Organism Count",
        selectedOption: .init(get: {
          viewModel.controls.minOrganismCount
        }, set: { newValue in
          viewModel.controls.minOrganismCount = newValue
        }),
        options: [0, 1, 10, 100, 1000]
      )
      ControlPicker(
        title: "Shelter Count",
        selectedOption: .init(get: {
          viewModel.controls.shelterCount
        }, set: { newValue in
          viewModel.controls.shelterCount = newValue
        }),
        options: [0, 1, 10, 50]
      )
      ControlPicker(
        title: "Metal Iterations",
        selectedOption: .init(get: {
          viewModel.controls.iterationCount
        }, set: { newValue in
          viewModel.controls.iterationCount = newValue
        }),
        options: [1, 10, 100, 1000, 10000, 100000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵"]
      )
      ControlPicker(
        title: "Refresh Rate",
        selectedOption: .init(get: {
          viewModel.controls.refreshRate
        }, set: { newValue in
          viewModel.controls.refreshRate = newValue
        }),
        options: [1, 24, 60, 120, 240]
      )
      ControlTextField(
        "Movement Limit",
        value: .init(get: {
          viewModel.controls.movementLimit
        }, set: { newValue in
          viewModel.controls.movementLimit = newValue
        })
      )
      ControlTextField(
        "Segment Size",
        value: .init(get: {
          viewModel.controls.segmentSize
        }, set: { newValue in
          viewModel.controls.segmentSize = newValue
        })
      )
      ControlTextField(
        "Min Starting Energy",
        value: .init(get: {
          viewModel.controls.minStartingEnergy
        }, set: { newValue in
          viewModel.controls.minStartingEnergy = newValue
        })
      )
      ControlTextField(
        "Max Starting Energy",
        value: .init(get: {
          viewModel.controls.maxStartingEnergy
        }, set: { newValue in
          viewModel.controls.maxStartingEnergy = newValue
        })
      )
      ControlTextField(
        "Shelter Energy Gain",
        value: .init(get: {
          viewModel.controls.shelterEnergyGainRate
        }, set: { newValue in
          viewModel.controls.shelterEnergyGainRate = newValue
        })
      )
      ControlTextField(
        "Division Threshold",
        value: .init(get: {
          viewModel.controls.divisionThreshold
        }, set: { newValue in
          viewModel.controls.divisionThreshold = newValue
        })
      )
      ControlTextField(
        "Shelter Reset Interval",
        value: .init(get: {
          viewModel.controls.shelterResetInterval
        }, set: { newValue in
          viewModel.controls.shelterResetInterval = newValue
        })
      )
      ControlToggle(
        title: "Dead Organisms Become Shelters",
        isOn: .init(get: {
          viewModel.controls.deadOrganismsBecomeShelters
        }, set: { newValue in
          viewModel.controls.deadOrganismsBecomeShelters = newValue
        })
      )
      ForEach(ids) { id in
        OrganismControl(id: id)
      }
    }
    .pickerStyle(.segmented)
  }
}

#Preview(traits: .previewData) {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}


struct ControlButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
    .symbolVariant(.fill)
      .symbolVariant(.circle)
      .foregroundStyle(.primary, .quinary)
      .font(.title)
      .imageScale(.large)
      .buttonStyle(.plain)
  }
}

struct SquareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .labelStyle(SquareButtonLabelStyle())
      .foregroundStyle(.primary, .primary)
      .font(.title)
      .imageScale(.large)
      .buttonStyle(.plain)
      .padding(8)
      .background {
        RoundedRectangle(cornerRadius: 8)
          .fill(.quinary)
      }
  }
}

struct SquareButtonLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack {
      configuration.icon
      configuration.title
        .foregroundStyle(.primary)
        .font(.body)
    }
  }
}

struct ControlToggle: View {
  let title: String
  @Binding var isOn: Bool
  
  var body: some View {
    HStack {
      Text(title)
        .font(.body)
      Spacer()
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(.indigo)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .background {
      RoundedRectangle(cornerRadius: 8)
        .fill(.quinary)
    }
  }
}


