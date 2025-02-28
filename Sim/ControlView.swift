//
//  ControlView.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI
import Combine

struct ControlTextField: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  @State private var text: String = ""
  
  init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double) {
    self.title = title
    self._value = value
    self.range = range
    self.step = step
    self._text = State(initialValue: value.wrappedValue.description)
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      TextField("Value", text: $text)
        .textFieldStyle(.roundedBorder)
        .onChange(of: text) { newValue in
          if let value = Double(newValue) {
            self.value = value
          }
        }
    }
  }
}

struct ControlView: View {

  @State var organisms: [Organism] = []
  @State var cancellables = Set<AnyCancellable>()
  @ObservedObject var viewModel: EcosystemViewModel

  var body: some View {
    List {
        playbackSection
          .listRowSeparator(.hidden, edges: .all)
        controlsSection
          .listRowSeparator(.hidden, edges: .all)
    }
    .symbolVariant(.fill)
    .symbolVariant(.circle)
    .imageScale(.large)
    .navigationSplitViewColumnWidth(200)
    .padding()
  }


  // MARK: - View Components

  private var playbackSection: some View {
    Section("Playback") {
      HStack {
        Button(action: {
           viewModel.togglePlayback()
        }) {
          Image(systemName: viewModel.isPlaying ? "pause" : "play")
            .font(.title)
        }
        Button(action: {
          viewModel.reset()
        }) {
          Image(systemName: "arrow.counterclockwise")
            .foregroundStyle(.primary)
            .font(.title)
        }
      }
      ControlTextField("Frame Rate", value: $viewModel.frameRate, in: 1...2000, step: 1)
      Text("\(Int(viewModel.movesPerSecond)) mps")
        .font(.title3)
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.black, .black.secondary, .black.tertiary)
  }

  private var controlsSection: some View {
    Section("Controls") {
      Button(action: {
        viewModel.addRandomOrganism()
      }) {
        Image(systemName: "plus")
          .font(.title)
      }
      ControlTextField("Movement Limit", value: $viewModel.movementLimit, in: 0...0.2, step: 0.01)
      ControlTextField("Segment Size", value: $viewModel.segmentSize, in: 0...100, step: 1)
      ControlTextField("Merge Sensitivity", value: $viewModel.mergeSensitivity, in: 0...100, step: 1)
      ControlTextField("Refresh Rate", value: $viewModel.refreshRate, in: 0...120, step: 1)
      ControlTextField("Organism Count", value: $viewModel.organismCount, in: 0...100000, step: 1000)
      ControlTextField("Chunk Size", value: $viewModel.chunkSize, in: 1...1000, step: 100)
      ForEach(organisms) { organism in
        OrganismControl(organism: organism)
      }
    }
  }
}

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ControlView(viewModel: viewModel)
}
