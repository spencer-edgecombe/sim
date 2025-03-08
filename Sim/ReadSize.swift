//
//  ReadSize.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/4/25.
//

import SwiftUI


struct ReadSizeModifier: ViewModifier {
  @Binding var size: CGSize
  func body(content: Content) -> some View {
    content.background(GeometryReader { geometry in
      Color.clear
        .onChange(of: geometry.size) {
          self.size = geometry.size
        }
    })
  }
}

extension View {
  func readSize(_ size: Binding<CGSize>) -> some View {
    modifier(ReadSizeModifier(size: size))
  }
}
