//
//  ControlTextField.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/2/25.
//

import SwiftUI

protocol ConvertsFromString {
  init?(_ string: String)
}

// Add conformance extensions for the required types
extension Double: ConvertsFromString {}
extension Float: ConvertsFromString {}
extension Int: ConvertsFromString {}

struct ControlTextField<Value: ConvertsFromString>: View {
  let title: String
  @Binding var value: Value
  @State private var text: String = ""
  @FocusState private var isFocused: Bool

  init(_ title: String, value: Binding<Value>) {
    self.title = title
    self._value = value
    self._text = State(initialValue: String(describing: value.wrappedValue))
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 4) {
        Text(title + ":")
          .foregroundColor(.secondary)
        HStack {
          TextField("Value", text: $text)
            .textFieldStyle(.plain)
            .frame(width: max(48.0, CGFloat(text.count * 10)))
            .onChange(of: text) {
              if let newValue = Value(text) {
                self.value = newValue
              }
            }
            .focused($isFocused)
        }
        .overlay {
          VStack {
            Spacer()
            Rectangle()
              .fill(isFocused ? .secondary : .tertiary)
              .frame(height: 1)
          }
        }
        Button(action: {
          isFocused = true
          text = ""
        }) {
          Image(systemName: "xmark.circle")
            .font(.caption)
        }
        .symbolRenderingMode(.hierarchical)
      }
    }
    .font(.subheadline)
  }
}

#Preview {
  @Previewable @StateObject var viewModel = EcosystemViewModel()

  ContentView(viewModel: viewModel)
}
