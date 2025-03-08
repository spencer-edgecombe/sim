//
//  ControlPicker.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/2/25.
//

import SwiftUI

struct ControlPicker<Value: Hashable & CustomStringConvertible>: View {
  let title: String
  @Binding var selectedOption: Value
  var options: [Value]
  var labels: [String]? = nil
  var onChange: ((Value) -> Void)? = nil
  
  // Special initializer for numeric types
  init(title: String, selectedOption: Binding<Double>, options: [Double], labels: [String]? = nil, onChange: ((Double) -> Void)? = nil) where Value == Double {
    self.title = title
    self._selectedOption = selectedOption
    self.options = options
    self.labels = labels
    self.onChange = onChange
  }
  
  // Special initializer for Int
  init(title: String, selectedOption: Binding<Int>, options: [Int], labels: [String]? = nil, onChange: ((Int) -> Void)? = nil) where Value == Int {
    self.title = title
    self._selectedOption = selectedOption
    self.options = options
    self.labels = labels
    self.onChange = onChange
  }
  
  // Generic initializer
  init(title: String, selectedOption: Binding<Value>, options: [Value], labels: [String]? = nil, onChange: ((Value) -> Void)? = nil) {
    self.title = title
    self._selectedOption = selectedOption
    self.options = options
    self.labels = labels
    self.onChange = onChange
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Picker(selection: $selectedOption, label: Text("")) {
        ForEach(options.indices, id: \.self) { index in
          if let label = labels?[index] {
            Text(label).tag(options[index])
          } else if let doubleValue = options[index] as? Double {
            Text(NumberFormatter.localizedString(from: NSNumber(value: doubleValue), number: .decimal))
              .tag(options[index])
          } else if let intValue = options[index] as? Int {
            Text(NumberFormatter.localizedString(from: NSNumber(value: intValue), number: .decimal))
              .tag(options[index])
          } else {
            Text(options[index].description)
              .tag(options[index])
          }
        }
      }
      .buttonStyle(.bordered)
    }
  }
}

#Preview {
  ControlPicker(title: "Picker", selectedOption: .constant(1), options: [1, 2, 3], onChange: nil)
    .pickerStyle(.menu)
}
