import SwiftUI

/// A view that displays controls for a single organism
struct OrganismControl: View {
  var organism: Organism

  var body: some View {

        Button("Grow") {
//          organism.grow()
        }
        
        Button("Duplicate") {
          Task {
            await Ecosystem.shared.duplicateOrganism(organism)
          }
    }
  }
}
