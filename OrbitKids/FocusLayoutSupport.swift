import SwiftUI

/// PreferenceKey to report the global Y-position (minY) of the first row of bottom buttons.
/// Attach the `reportFirstButtonsRowTop()` modifier to the FIRST row view of your buttons container.
public struct FirstButtonsRowTopPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        // Prefer non-zero measurements; fall back to existing value otherwise
        if next > 0 { value = next } else if value == 0 { value = next }
    }
}

public extension View {
    /// Reports the global minY of the view to the parent using `FirstButtonsRowTopPreferenceKey`.
    /// Place this on the FIRST button row (e.g., your HStack/VStack that represents the first line of buttons).
    /// Beispiel:
    /// HStack { ... }
    ///   .reportFirstButtonsRowTop()
    func reportFirstButtonsRowTop() -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: FirstButtonsRowTopPreferenceKey.self,
                                value: geo.frame(in: .global).minY)
            }
        )
    }
}
