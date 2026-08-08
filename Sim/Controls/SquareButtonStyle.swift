//
//  SquareButtonStyle.swift
//  Sim
//
//  Created by Spencer Edgecombe on 2/25/25.
//

import SwiftUI

/// A button style that places its label inside a rounded-rectangle background.
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

/// A label style used by ``SquareButtonStyle`` that stacks the icon above the title.
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
