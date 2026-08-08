//
//  ControlToggle.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI

/// A labeled toggle control styled to match the control panel aesthetic.
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
