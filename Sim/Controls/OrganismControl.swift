import SwiftUI

/// A view that displays controls for a single organism
struct OrganismControl: View {
  var id: SimID

  var body: some View {

        Button("Grow") {
          Task {
            await Ecosystem.shared.growOrganism(id: id)
          }
        }
        
        Button("Duplicate") {
          Task {
            await Ecosystem.shared.duplicateOrganism(id)
          }
    }
  }
}
