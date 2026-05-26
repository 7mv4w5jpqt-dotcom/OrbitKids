import SwiftUI

struct LitBodyView: View {
    let radius: CGFloat
    let bodyColor: Color
    let sunPosition: CGPoint
    let bodyPosition: CGPoint

    var body: some View {
        let toSunAngle = angle(from: bodyPosition, to: sunPosition)

        ZStack {
            Circle().fill(bodyColor)

            // Day/Night shading only
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            bodyColor,
                            Color.black.opacity(0.85)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.radians(toSunAngle + .pi))

        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func angle(from a: CGPoint, to b: CGPoint) -> Double {
        Double(atan2(b.y - a.y, b.x - a.x))
    }
}
