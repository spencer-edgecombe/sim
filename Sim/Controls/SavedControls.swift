import SwiftUI
import SwiftData

/// A SwiftData model that persists a named ``Controls`` configuration.
@Model
class SavedControls {
  var name: String
  var controls: Controls?

  init(
    name: String,
    controls: Controls
  ) {
    self.name = name
    self.controls = controls
  }
}
