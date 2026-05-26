import SwiftUI

struct SunView: View {
    // Optional callback when the sun is tapped/clicked
    var onTap: (() -> Void)? = nil

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.yellow,
                        Color.orange.opacity(0.9),
                        Color.orange.opacity(0.4)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 34
                )
            )
            // Improve hit testing and forward taps
            .contentShape(Circle())
            .onTapGesture { onTap?() }
            .accessibilityLabel("Sonne")
            .accessibilityAddTraits(.isButton)
    }
}
