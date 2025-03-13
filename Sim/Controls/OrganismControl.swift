import SwiftUI

/// A view that displays controls for a single organism
struct OrganismControl: View {
  var id: SimID

  var body: some View {
    Text("\(id.identifier)")
  }
}
