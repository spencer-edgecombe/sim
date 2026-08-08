//
//  PreviewContainer.swift
//  Sim
//
//  Created by Spencer Edgecombe on 3/22/25.
//

import SwiftData
import Foundation
import SwiftUI

extension ModelContainer {
  @MainActor static let preview: ModelContainer = {
    let container = try! ModelContainer(for: SavedControls.self, configurations: .init(isStoredInMemoryOnly: true))

    var controls = Controls()
    controls.organismCount = 1
    controls.shelterCount = 1
    controls.iterationCount = 1
    container.mainContext.insert(SavedControls(name: "Preview", controls: controls))

    try? container.mainContext.save()
    return container
  }()
}

struct PreviewCotainer: PreviewModifier {
  static func makeSharedContext() async throws -> ModelContainer {
    .preview
  }

  func body(content: Content, context: ModelContainer) -> some View {
      content
        .modelContainer(context)
  }
}

extension PreviewTrait<Preview.ViewTraits> {
  static var previewData: Self {
    modifier(PreviewCotainer())
  }
}



