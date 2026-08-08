//
//  ControlButtonStyle.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI

/// A button style used in the ``ControlView`` toolbar that renders buttons as filled, circular SF Symbols.
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
