import SwiftUI

struct ControlSlider: View {
  var title: String
  @Binding var value: Double
  var range: ClosedRange<Double>
  var step: Double

  init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double) {
    self.title = title
    self._value = value
    self.range = range
    self.step = step
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      HStack {
        Text(value.description)
          .layoutPriority(2)
        Slider(value: $value, in: range, step: step)
      }
    }
    
  }
}
