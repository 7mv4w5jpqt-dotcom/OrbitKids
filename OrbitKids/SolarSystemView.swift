import SwiftUI
import Combine
import UIKit

struct SolarSystemView: View {

    // Orbit-Radien
    private let mercuryOrbitRadius: CGFloat = 90
    private let venusOrbitRadius: CGFloat = 150
    private let earthOrbitRadius: CGFloat = 210
    private let moonOrbitRadius: CGFloat = 40
    private let marsOrbitRadius: CGFloat = 270
    private let jupiterOrbitRadius: CGFloat = 430
    private let saturnOrbitRadius: CGFloat = 520
    private let uranusOrbitRadius: CGFloat = 620
    private let neptuneOrbitRadius: CGFloat = 700

    // Umlaufzeiten (in Tagen)
    private let earthPeriodDays: Double = 365.0
    private let moonPeriodDays: Double = 27.3
    private let venusPeriodDays: Double = 224.7
    private let mercuryPeriodDays: Double = 87.97
    private let marsPeriodDays: Double = 687.0
    private let jupiterPeriodDays: Double = 4331.0
    private let saturnPeriodDays: Double = 10759.0
    private let uranusPeriodDays: Double = 30687.0
    private let neptunePeriodDays: Double = 60190.0

    // Logarithmische Simulationsgeschwindigkeit
    @State private var logSpeed: Double = log(8)   // Start bei 8×
    private let minLogSpeed: Double = log(1)       // 1 Tag pro Sekunde
    private let maxLogSpeed: Double = log(500)     // 500×

    @State private var zoom: CGFloat = 1.0
    @State private var focus: FocusTarget = .sun
    @FocusState private var focusedTarget: FocusTarget?

    @State private var panBase: CGSize = .zero
    @State private var panAccum: CGSize = .zero

    @State private var simDays: Double = 0
    @State private var accumulator: TimeInterval = 0
    private let fixedDT: TimeInterval = 1.0 / 60.0
    private let maxFrameDT: TimeInterval = 1.0 / 15.0

    @State private var displayLink: CADisplayLink?

    // Startsequenz
    @State private var showStartSequence = true
    private let visibleMovementThreshold: Double = 3.0

    // Dynamische Höhe des Button-Bereichs
    @State private var buttonAreaHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in

            // Safe Areas
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom

            // Bereich zwischen Statusbar und Buttons
            let topLimit = safeTop
            let bottomLimit = geo.size.height - buttonAreaHeight - safeBottom

            // Optische Mitte des freien Bereichs
            let visualCenterY = (topLimit + bottomLimit) / 2

            let center = CGPoint(x: geo.size.width / 2,
                                 y: geo.size.height / 2)

            let focusPos = positionOf(focus,
                                      simDays: simDays,
                                      center: center)

            ZStack {

                // STARTSEQUENZ
                if showStartSequence {
                    ContentView()
                        .transition(.opacity)
                        .zIndex(10)
                }

                // ZOOM + SPEED + PAN
                ZoomableSolarSystemView(
                    zoom: $zoom,
                    logSpeed: $logSpeed,
                    minLogSpeed: minLogSpeed,
                    maxLogSpeed: maxLogSpeed
                ) {
                    solarSystemContent(center: center, simDays: simDays)
                        .offset(
                            x: center.x - focusPos.x + panAccum.width / max(zoom, 0.0001),
                            y: visualCenterY - focusPos.y + panAccum.height / max(zoom, 0.0001)
                        )
                        .scaleEffect(zoom)
                        .animation(.easeInOut(duration: 0.8), value: focus)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            panAccum = CGSize(
                                width: panBase.width + value.translation.width,
                                height: panBase.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            panBase = CGSize(
                                width: panBase.width + value.translation.width,
                                height: panBase.height + value.translation.height
                            )
                        }
                )
                .background(Color.black.ignoresSafeArea())

                // UI-Overlay
                VStack {
                    Spacer()

                    // Buttons (dynamisch gemessen)
                    WrapLayout(spacing: 12) {
                        ForEach(FocusTarget.allCases, id: \.self) { target in
                            Button {
                                select(target)
                            } label: {
                                Text(target.rawValue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.black.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(
                                                Color.white.opacity(focus == target ? 0.85 : 0.25),
                                                lineWidth: focus == target ? 2.2 : 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
                                    .foregroundColor(.white)
                            }
                            .focused($focusedTarget, equals: target)
                        }
                    }
                    .padding(.horizontal, 20)
                    .background(
                        GeometryReader { buttonGeo in
                            Color.clear
                                .onAppear {
                                    buttonAreaHeight = buttonGeo.size.height + 24
                                }
                                .onChange(of: buttonGeo.size.height) { _, newValue in
                                    buttonAreaHeight = newValue + 24
                                }
                        }
                    )

                    // Tag-Anzeige
                    Text("Tag \(Int(simDays.truncatingRemainder(dividingBy: 365))) von 365")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.black.opacity(0.08))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear { startDisplayLink() }
        .onDisappear { displayLink?.invalidate() }
        .onChange(of: simDays) { _, newValue in
            if showStartSequence && newValue > visibleMovementThreshold {
                withAnimation(.easeOut(duration: 1.0)) {
                    showStartSequence = false
                }
            }
        }
    }

    // MARK: - DisplayLink Simulation

    private func startDisplayLink() {
        let proxy = DisplayLinkProxy { dt in
            stepSimulation(dt: dt)
        }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .default)
        displayLink = link
    }

    private func stepSimulation(dt: Double) {
        let clamped = min(max(dt, 0), maxFrameDT)
        accumulator += clamped

        while accumulator >= fixedDT {
            let daysPerSecond = exp(logSpeed)
            simDays += daysPerSecond * fixedDT
            accumulator -= fixedDT
        }
    }

    private func select(_ target: FocusTarget) {
        focus = target
        focusedTarget = target
        panBase = .zero
        panAccum = .zero
    }

    // MARK: - Sonnensystem Inhalt

    private func solarSystemContent(center: CGPoint, simDays: Double) -> some View {
        ZStack {

            SunView(onTap: { select(.sun) })
                .frame(width: 70, height: 70)
                .contentShape(Circle())
                .position(center)

            planet(radius: 3, color: .gray.opacity(0.9),
                   orbitRadius: mercuryOrbitRadius,
                   period: mercuryPeriodDays,
                   simDays: simDays, center: center,
                   target: .mercury)

            planet(radius: 7,
                   color: Color(red: 0.95, green: 0.85, blue: 0.6),
                   orbitRadius: venusOrbitRadius,
                   period: venusPeriodDays,
                   simDays: simDays, center: center,
                   target: .venus)

            EarthMoonSystemView(
                center: center,
                simDays: simDays,
                earthOrbitRadius: earthOrbitRadius,
                moonOrbitRadius: moonOrbitRadius,
                earthPeriodDays: earthPeriodDays,
                moonPeriodDays: moonPeriodDays,
                onTapEarth: { select(.earth) },
                onTapMoon: { select(.moon) }
            )

            planet(radius: 6,
                   color: Color(red: 0.9, green: 0.4, blue: 0.2),
                   orbitRadius: marsOrbitRadius,
                   period: marsPeriodDays,
                   simDays: simDays, center: center,
                   target: .mars)

            planet(radius: 20,
                   color: Color(red: 0.9, green: 0.75, blue: 0.5),
                   orbitRadius: jupiterOrbitRadius,
                   period: jupiterPeriodDays,
                   simDays: simDays, center: center,
                   target: .jupiter)

            saturn(simDays: simDays, center: center)

            planet(radius: 12,
                   color: Color(red: 0.6, green: 0.85, blue: 0.9),
                   orbitRadius: uranusOrbitRadius,
                   period: uranusPeriodDays,
                   simDays: simDays, center: center,
                   target: .uranus)

            planet(radius: 12,
                   color: Color(red: 0.4, green: 0.6, blue: 1.0),
                   orbitRadius: neptuneOrbitRadius,
                   period: neptunePeriodDays,
                   simDays: simDays, center: center,
                   target: .neptune)
        }
    }

    // MARK: - Generischer Planet

    private func planet(radius: CGFloat,
                        color: Color,
                        orbitRadius: CGFloat,
                        period: Double,
                        simDays: Double,
                        center: CGPoint,
                        target: FocusTarget) -> some View {

        let angle = 2 * .pi * (simDays / period)
        let pos = CGPoint(
            x: center.x + orbitRadius * CGFloat(cos(angle)),
            y: center.y + orbitRadius * CGFloat(sin(angle))
        )

        return LitBodyView(
            radius: radius,
            bodyColor: color,
            sunPosition: center,
            bodyPosition: pos
        )
        .contentShape(Circle())
        .onTapGesture { select(target) }
        .accessibilityLabel(target.rawValue)
        .accessibilityAddTraits(.isButton)
        .position(pos)
    }

    // MARK: - Fokus-Position

    private func positionOf(_ target: FocusTarget,
                            simDays: Double,
                            center: CGPoint) -> CGPoint {
        switch target {
        case .sun:
            return center
        case .mercury:
            return pointOnOrbit(radius: mercuryOrbitRadius,
                                period: mercuryPeriodDays,
                                simDays: simDays,
                                center: center)
        case .venus:
            return pointOnOrbit(radius: venusOrbitRadius,
                                period: venusPeriodDays,
                                simDays: simDays,
                                center: center)
        case .earth:
            return pointOnOrbit(radius: earthOrbitRadius,
                                period: earthPeriodDays,
                                simDays: simDays,
                                center: center)
        case .moon:
            let earthAngle = 2 * .pi * (simDays / earthPeriodDays)
            let earthPos = CGPoint(
                x: center.x + earthOrbitRadius * CGFloat(cos(earthAngle)),
                y: center.y + earthOrbitRadius * CGFloat(sin(earthAngle))
            )
            let moonAngle = 2 * .pi * (simDays / moonPeriodDays)
            return CGPoint(
                x: earthPos.x + moonOrbitRadius * CGFloat(cos(moonAngle)),
                y: earthPos.y + moonOrbitRadius * CGFloat(sin(moonAngle))
            )
        case .mars:
            return pointOnOrbit(radius: marsOrbitRadius,
                                period: marsPeriodDays,
                                simDays: simDays,
                                center: center)
        case .jupiter:
            return pointOnOrbit(radius: jupiterOrbitRadius,
                                period: jupiterPeriodDays,
                                simDays: simDays,
                                center: center)
        case .saturn:
            return pointOnOrbit(radius: saturnOrbitRadius,
                                period: saturnPeriodDays,
                                simDays: simDays,
                                center: center)
        case .uranus:
            return pointOnOrbit(radius: uranusOrbitRadius,
                                period: uranusPeriodDays,
                                simDays: simDays,
                                center: center)
        case .neptune:
            return pointOnOrbit(radius: neptuneOrbitRadius,
                                period: neptunePeriodDays,
                                simDays: simDays,
                                center: center)
        }
    }

    private func pointOnOrbit(radius: CGFloat,
                              period: Double,
                              simDays: Double,
                              center: CGPoint) -> CGPoint {
        let angle = 2 * .pi * (simDays / period)
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    // MARK: - Saturn mit Ringen

    private func saturn(simDays: Double, center: CGPoint) -> some View {
        let angle = 2 * .pi * (simDays / saturnPeriodDays)
        let pos = CGPoint(
            x: center.x + saturnOrbitRadius * CGFloat(cos(angle)),
            y: center.y + saturnOrbitRadius * CGFloat(sin(angle))
        )

        let outerWidth: CGFloat = 128
        let outerHeight: CGFloat = 30
        let innerScale: CGFloat = 0.60
        let tilt: Angle = .degrees(26.7)

        let ringGradient = LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.85), location: 0.05),
                .init(color: Color(red: 0.86, green: 0.80, blue: 0.70).opacity(0.80), location: 0.35),
                .init(color: Color(red: 0.78, green: 0.72, blue: 0.62).opacity(0.75), location: 0.65),
                .init(color: Color(red: 0.72, green: 0.66, blue: 0.56).opacity(0.70), location: 0.95)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )

        return ZStack {
            AnnulusShape(innerScale: innerScale)
                .fill(ringGradient, style: FillStyle(eoFill: true))
                .overlay(
                    AnnulusShape(innerScale: innerScale)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .clipShape(TopHalf())
                .rotationEffect(tilt)
                .frame(width: outerWidth, height: outerHeight)

            LitBodyView(
                radius: 14,
                bodyColor: Color(red: 0.9, green: 0.8, blue: 0.6),
                sunPosition: center,
                bodyPosition: pos
            )

            AnnulusShape(innerScale: innerScale)
                .fill(ringGradient, style: FillStyle(eoFill: true))
                .overlay(
                    AnnulusShape(innerScale: innerScale)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                )
                .clipShape(BottomHalf())
                .rotationEffect(tilt)
                .frame(width: outerWidth, height: outerHeight)
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { select(.saturn) }
        .accessibilityLabel(FocusTarget.saturn.rawValue)
        .accessibilityAddTraits(.isButton)
        .position(pos)
    }
}

// MARK: - DisplayLink Proxy

class DisplayLinkProxy {
    let callback: (Double) -> Void
    init(_ callback: @escaping (Double) -> Void) {
        self.callback = callback
    }

    @objc func tick(_ link: CADisplayLink) {
        callback(link.targetTimestamp - link.timestamp)
    }
}

// MARK: - Helpers for Saturn's rings

private struct AnnulusShape: Shape {
    var innerScale: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect)
        let dx = rect.width * (1 - innerScale) / 2
        let dy = rect.height * (1 - innerScale) / 2
        let innerRect = rect.insetBy(dx: dx, dy: dy)
        p.addEllipse(in: innerRect)
        return p
    }
}

private struct TopHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: 0, y: 0, width: rect.width, height: rect.height / 2))
        return p
    }
}

private struct BottomHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(
            CGRect(
                x: 0,
                y: rect.height / 2,
                width: rect.width,
                height: rect.height / 2
            )
        )
        return p
    }
}
