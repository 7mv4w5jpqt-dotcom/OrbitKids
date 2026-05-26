import SwiftUI

struct EarthMoonSystemView: View {

    let center: CGPoint
    let simDays: Double

    let earthOrbitRadius: CGFloat
    let moonOrbitRadius: CGFloat

    let earthPeriodDays: Double
    let moonPeriodDays: Double

    let onTapEarth: (() -> Void)?
    let onTapMoon: (() -> Void)?

    var body: some View {

        // Erde auf ihrer Umlaufbahn
        let earthAngle = 2 * .pi * (simDays / earthPeriodDays)
        let earthPos = CGPoint(
            x: center.x + earthOrbitRadius * CGFloat(cos(earthAngle)),
            y: center.y + earthOrbitRadius * CGFloat(sin(earthAngle))
        )

        // Mond um die Erde
        let moonAngle = 2 * .pi * (simDays / moonPeriodDays)
        let moonPos = CGPoint(
            x: earthPos.x + moonOrbitRadius * CGFloat(cos(moonAngle)),
            y: earthPos.y + moonOrbitRadius * CGFloat(sin(moonAngle))
        )

        let sunPos = center

        return ZStack {

            // Atmosphärischer Glow der Erde
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.25),
                            Color.blue.opacity(0.05),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 8 * 2 + 12, height: 8 * 2 + 12)
                .position(earthPos)
                .allowsHitTesting(false)

            // Mond
            LitBodyView(
                radius: 2.5,
                bodyColor: .gray,
                sunPosition: sunPos,
                bodyPosition: moonPos
            )
            .contentShape(Circle())
            .onTapGesture { onTapMoon?() }
            .accessibilityLabel("Mond")
            .accessibilityAddTraits(.isButton)
            .position(moonPos)

            // Erde
            LitBodyView(
                radius: 8,
                bodyColor: .blue,
                sunPosition: sunPos,
                bodyPosition: earthPos
            )
            .contentShape(Circle())
            .onTapGesture { onTapEarth?() }
            .accessibilityLabel("Erde")
            .accessibilityAddTraits(.isButton)
            .position(earthPos)
        }
    }
}
