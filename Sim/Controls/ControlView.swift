//
//  ControlView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI
import Combine

struct ControlView: View {

  @State var ids: [SimID] = []
  @State var cancellables = Set<AnyCancellable>()
  @ObservedObject var viewModel: EcosystemViewModel

  var body: some View {
    List {
      playbackSection
        .listRowSeparator(.hidden, edges: .all)
      controlsSection
        .listRowSeparator(.hidden, edges: .all)
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
    .symbolVariant(.fill)
    .symbolVariant(.circle)
    .tint(.orange)
    .imageScale(.large)
    .buttonStyle(.plain)
  }


  // MARK: - View Components

  private var playbackSection: some View {
    Group {
      Text("\(Int(viewModel.movesPerSecond)) mps")
        .font(.title)
        .fontWeight(.bold)
      Text("\(ids.count) organisms")
        .font(.title)
        .fontWeight(.bold)
      HStack {
        Button(action: {
          Task {
            await viewModel.togglePlayback()
          }
        }) {
          Image(systemName: viewModel.isPlaying ? "pause" : "play")
            .font(.title)
        }
        Button(action: {
          viewModel.step()
        }) {
          Image(systemName: "forward")
            .foregroundStyle(.primary)
            .font(.title)
        }
        .help("Step forward one iteration")
        Button(action: {
          viewModel.reset()
        }) {
          Image(systemName: "arrow.counterclockwise")
            .foregroundStyle(.primary)
            .font(.title)
        }
        Button(action: {
          viewModel.addRandomOrganism()
        }) {
          ZStack {
            Image(systemName: "circle.badge.plus")
              .foregroundStyle(.primary, .clear)
              .symbolRenderingMode(.none)
            Image(systemName: "questionmark")
              .foregroundStyle(.primary)
          }
          .font(.title)
        }
      }
      Divider()
      ControlTextField("Frame Rate", value: .init(get: {
        Double(viewModel.controls.refreshRate)
      }, set: { newValue in
        viewModel.controls.refreshRate = Int(newValue)
      }))
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.black, .black.secondary, .black.tertiary)
  }

  private var controlsSection: some View {
    Group {
      ControlPicker(
        title: "Organism Count",
        selectedOption: .init(get: {
          viewModel.controls.organismCount
        }, set: { newValue in
          viewModel.controls.organismCount = newValue
        }),
        options: [1, 10, 100, 1000, 10000, 100000, 1000000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵", "10⁶"]
      )
      ControlPicker(
        title: "Min Organism Count",
        selectedOption: .init(get: {
          viewModel.controls.minOrganismCount
        }, set: { newValue in
          viewModel.controls.minOrganismCount = newValue
        }),
        options: [0, 10, 25, 50, 100, 250, 500]
      )
      ControlPicker(
        title: "Shelter Count",
        selectedOption: .init(get: {
          viewModel.controls.shelterCount
        }, set: { newValue in
          viewModel.controls.shelterCount = newValue
        }),
        options: [1, 5, 10, 20, 50, 100]
      )
      ControlPicker(
        title: "Metal Iterations",
        selectedOption: .init(get: {
          viewModel.controls.iterationCount
        }, set: { newValue in
          viewModel.controls.iterationCount = newValue
        }),
        options: [1, 10, 100, 1000, 10000, 100000, 1000000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵", "10⁶"]
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
      ForEach(ids) { id in
        OrganismControl(id: id)
      }
    }
    .pickerStyle(.menu)
  }
}

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
