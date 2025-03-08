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
      await Ecosystem.shared.organismIDPublisher
        .sink { ids in
          Task { @MainActor in
            self.ids = ids
          }
        }
        .store(in: &cancellables)
    }
    .symbolVariant(.fill)
    .symbolVariant(.circle)
    .imageScale(.large)
    .padding()
    .buttonStyle(.plain)
    .listStyle(.bordered)
  }


  // MARK: - View Components

  private var playbackSection: some View {
    Group {
      Text("\(Int(viewModel.movesPerSecond)) mps")
        .font(.title)
        .fontWeight(.bold)
      HStack {
        Button(action: {
           viewModel.togglePlayback()
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
        Button(action: {
          viewModel.editingWipOrganism.toggle()
        }) {
          ZStack {
            Image(systemName: "circle.badge.\( viewModel.editingWipOrganism ?  "minus" : "plus")")
              .foregroundStyle(.primary, .clear)
              .symbolRenderingMode(.none)
            Image(systemName: "pencil")          .symbolVariant(.none)
          }
          .font(.title)
        }

      }
      if viewModel.editingWipOrganism {
        Text("Start")
          .font(.headline)
        HStack {
          ControlTextField("x", value: $viewModel.wipOrganismStartX)
          ControlTextField("y", value: $viewModel.wipOrganismStartY)
        }
          ForEach(viewModel.wipOrganismMovementAngle.indices, id: \.self) { i in
            Text("Segment \(i + 1)")
              .bold()
              .padding(.top, 8)

              ControlTextField("Next", value: .init(get: {
                viewModel.wipOrganismNextPointAngle[i]
              }, set: { newValue in
                viewModel.wipOrganismNextPointAngle[i] = newValue
              }))
              ControlTextField("Movement", value: .init(get: {
                viewModel.wipOrganismMovementAngle[i]
              }, set: { newValue in
                viewModel.wipOrganismMovementAngle[i] = newValue
              }))
        }

        Button("Add segment", systemImage: "plus") {
          viewModel.addWipSegment()
        }
        .padding(.top, 8)
        Button("Done", systemImage: "checkmark") {
          viewModel.addWipSegment()
        }
      }
      Divider()
      ControlTextField("Frame Rate", value: $viewModel.frameRate)
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.black, .black.secondary, .black.tertiary)
  }

  private var controlsSection: some View {
    Group {
      ControlPicker(
        title: "Organism Count",
        selectedOption: $viewModel.organismCount,
        options: [1, 10, 100, 1000, 10000, 100000, 1000000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵", "10⁶"],
        onChange: nil
      )
      ControlPicker(
        title: "Metal Iterations",
        selectedOption: $viewModel.metalIterationCount,
        options: [1, 10, 100, 1000, 10000, 100000, 1000000],
        labels: ["1", "10", "10²", "10³", "10⁴", "10⁵", "10⁶"],
        onChange: nil
      )
      ControlPicker(
        title: "Refresh Rate",
        selectedOption: $viewModel.refreshRate,
        options: [1, 24, 60, 120, 240],
        onChange: nil
      )
      ControlTextField(
        "Movement Limit",
        value: $viewModel.movementLimit
      )
      ControlTextField(
        "Segment Size",
        value: $viewModel.segmentSize
      )
      ControlPicker(
        title: "Chunk Size",
        selectedOption: $viewModel.chunkSize,
        options: [1, 2, 3],
        onChange: nil
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
