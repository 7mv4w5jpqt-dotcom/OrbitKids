import SwiftUI
import Combine
import UIKit

struct SolarSystemView: View {

    // Orbit-Radien
    private let mercuryOrbitRadius: CGFloat = 90
    private let venusOrbitRadius: CGFloat = 165
    private let earthOrbitRadius: CGFloat = 230
    private let moonOrbitRadius: CGFloat = 32
    private let marsOrbitRadius: CGFloat = 350
    private let jupiterOrbitRadius: CGFloat = 470
    private let saturnOrbitRadius: CGFloat = 570
    private let uranusOrbitRadius: CGFloat = 675
    private let neptuneOrbitRadius: CGFloat = 760

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
    @State private var showGestureHelp = false
    @State private var showLanguagePicker = false
    @AppStorage("hasSeenGestureHelp") private var hasSeenGestureHelp = false
    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = AppLanguage.systemDefault.rawValue
    private let visibleMovementThreshold: Double = 3.0

    @State private var mouseControlRepeatTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in

            let center = CGPoint(x: geo.size.width / 2,
                                 y: geo.size.height / 2)

            let focusPos = positionOf(focus,
                                      simDays: simDays,
                                      center: center)
            let safeZoom = max(zoom, 0.0001)
            let focusOffset = CGSize(
                width: panAccum.width / safeZoom + center.x - focusPos.x,
                height: panAccum.height / safeZoom + center.y - focusPos.y
            )

            ZStack {

                // STARTSEQUENZ
                if showStartSequence {
                    LoadingView()
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
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(focusOffset)
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
                    WrapLayout(spacing: bottomButtonSpacing) {
                        Image(systemName: "info.circle")
                            .font(.system(size: controlIconSize, weight: .semibold))
                            .foregroundStyle(controlBlue)
                            .frame(width: controlIconFrameSize, height: controlIconFrameSize)
                            .contentShape(Rectangle())
                            .offset(y: controlIconVerticalOffset)
                            .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
                            .onTapGesture {
                                showGestureHelp = true
                            }
                            .accessibilityLabel(localizedText(.showGestureHelp))
                            .accessibilityAddTraits(.isButton)

                        Image(systemName: "globe")
                            .font(.system(size: controlIconSize, weight: .semibold))
                            .foregroundStyle(controlBlue)
                            .frame(width: controlIconFrameSize, height: controlIconFrameSize)
                            .contentShape(Rectangle())
                            .offset(y: controlIconVerticalOffset)
                            .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
                            .onTapGesture {
                                showLanguagePicker = true
                            }
                            .accessibilityLabel(localizedText(.chooseLanguage))
                            .accessibilityAddTraits(.isButton)

                        #if targetEnvironment(macCatalyst)
                        catalystMouseButton(
                            systemImage: "minus.magnifyingglass",
                            accessibilityLabel: localizedText(.zoomOut)
                        ) {
                            adjustZoom(by: 0.992)
                        }

                        catalystMouseButton(
                            systemImage: "plus.magnifyingglass",
                            accessibilityLabel: localizedText(.zoomIn)
                        ) {
                            adjustZoom(by: 1.008)
                        }

                        catalystMouseButton(
                            systemImage: "backward.fill",
                            accessibilityLabel: localizedText(.slowDown)
                        ) {
                            adjustSpeed(by: -0.03)
                        }

                        catalystMouseButton(
                            systemImage: "forward.fill",
                            accessibilityLabel: localizedText(.speedUp)
                        ) {
                            adjustSpeed(by: 0.03)
                        }
                        #endif

                        ForEach(FocusTarget.allCases, id: \.self) { target in
                            Button {
                                select(target)
                            } label: {
                                Text(target.displayName(for: currentLanguage))
                                    .font(bottomButtonFont)
                                    .padding(.horizontal, 7)
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

                        dayCounterView
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                        .frame(height: 12)
                }

                if showGestureHelp {
                    gestureHelpOverlay
                        .zIndex(20)
                }

                if showLanguagePicker {
                    languagePickerOverlay
                        .zIndex(21)
                }
            }
        }
        .onAppear { startDisplayLink() }
        .onDisappear {
            displayLink?.invalidate()
            #if targetEnvironment(macCatalyst)
            stopMouseControlRepeat()
            #endif
        }
        .onChange(of: simDays) { _, newValue in
            if showStartSequence && newValue > visibleMovementThreshold {
                withAnimation(.easeOut(duration: 1.0)) {
                    showStartSequence = false
                }

                if !hasSeenGestureHelp {
                    showGestureHelp = true
                    hasSeenGestureHelp = true
                }
            }
        }
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageRawValue) ?? .systemDefault
    }

    private var dayDisplayText: String {
        let day = Int(simDays.truncatingRemainder(dividingBy: 365))
        switch currentLanguage {
        case .german:
            return "Tag \(day) von 365"
        case .english:
            return "Day \(day) of 365"
        case .spanish:
            return "Día \(day) de 365"
        case .french:
            return "Jour \(day) sur 365"
        case .italian:
            return "Giorno \(day) di 365"
        case .portuguese:
            return "Dia \(day) de 365"
        }
    }

    private var dayCounterMaxText: String {
        switch currentLanguage {
        case .german:
            return "Tag 365 von 365"
        case .english:
            return "Day 365 of 365"
        case .spanish:
            return "Día 365 de 365"
        case .french:
            return "Jour 365 sur 365"
        case .italian:
            return "Giorno 365 di 365"
        case .portuguese:
            return "Dia 365 de 365"
        }
    }

    private var controlBlue: Color {
        Color(red: 0.18, green: 0.45, blue: 0.90)
    }

    private var bottomButtonSpacing: CGFloat {
        #if targetEnvironment(macCatalyst)
        8
        #else
        4
        #endif
    }

    private var bottomButtonFont: Font {
        #if targetEnvironment(macCatalyst)
        .body
        #else
        .subheadline
        #endif
    }

    private var controlIconSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        28
        #else
        24
        #endif
    }

    private var controlIconFrameSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        44
        #else
        30
        #endif
    }

    private var controlIconVerticalOffset: CGFloat {
        #if targetEnvironment(macCatalyst)
        -5
        #else
        0
        #endif
    }

    private var dayCounterFont: Font {
        #if targetEnvironment(macCatalyst)
        .headline.monospacedDigit()
        #else
        .subheadline.monospacedDigit()
        #endif
    }

    private var dayCounterView: some View {
        ZStack {
            Text(dayCounterMaxText)
                .hidden()

            Text(dayDisplayText)
        }
        .font(dayCounterFont)
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.black.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
    }

    #if targetEnvironment(macCatalyst)
    private func catalystMouseButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(controlBlue)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .offset(y: -5)
            .shadow(color: Color.black.opacity(0.5), radius: 1, y: 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        startMouseControlRepeat(action)
                    }
                    .onEnded { _ in
                        stopMouseControlRepeat()
                    }
            )
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }
    #endif

    private func localizedText(_ key: LocalizedTextKey) -> String {
        key.text(for: currentLanguage)
    }

    private var languagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    showLanguagePicker = false
                }

            VStack(alignment: .leading, spacing: 18) {
                Text(localizedText(.chooseLanguage))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)

                VStack(spacing: 8) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            selectedLanguageRawValue = language.rawValue
                            showLanguagePicker = false
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundStyle(.black)
                                Spacer()
                                if language == currentLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(controlBlue)
                                }
                            }
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.gray.opacity(0.14))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var gestureHelpOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    showGestureHelp = false
                }

            VStack(alignment: .leading, spacing: 18) {
                Text(localizedText(.gestureControlsTitle))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)

                VStack(alignment: .leading, spacing: 14) {
                    gestureHelpRow(
                        icon: "hand.draw.fill",
                        title: localizedText(.panTitle),
                        detail: localizedText(.panDetail)
                    )
                    speedGestureHelpRow(
                        title: localizedText(.speedTitle),
                        detail: localizedText(.speedDetail)
                    )
                    zoomGestureHelpRow(
                        title: localizedText(.zoomTitle),
                        detail: localizedText(.zoomDetail)
                    )
                    focusGestureHelpRow(
                        title: localizedText(.focusTitle),
                        detail: localizedText(.focusDetail)
                    )

                    #if targetEnvironment(macCatalyst)
                    gestureHelpRow(
                        icon: "cursorarrow",
                        title: localizedText(.withoutTrackpadTitle),
                        detail: localizedText(.withoutTrackpadDetail)
                    )
                    #endif
                }

                Button {
                    showGestureHelp = false
                } label: {
                    Text(localizedText(.understood))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray.opacity(0.22))
                .foregroundStyle(.black)
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func gestureHelpRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(controlBlue)
                .frame(width: 28, height: 28)

            gestureHelpText(title: title, detail: detail)
        }
    }

    private func speedGestureHelpRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            twoFingerSwipeUpIcon
                .frame(width: 28, height: 28)

            gestureHelpText(title: title, detail: detail)
        }
    }

    private func zoomGestureHelpRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            twoFingerZoomIcon
                .frame(width: 28, height: 28)

            gestureHelpText(title: title, detail: detail)
        }
    }

    private func focusGestureHelpRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            focusTapIcon
                .frame(width: 28, height: 28)
                .compositingGroup()

            gestureHelpText(title: title, detail: detail)
        }
    }

    private func gestureHelpText(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var focusTapIcon: some View {
        ZStack {
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.gray.opacity(0.68))

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(controlBlue)
                .rotationEffect(.degrees(-18))
                .offset(x: 9, y: 9)
        }
        .frame(width: 34, height: 34)
    }

    private var twoFingerSwipeUpIcon: some View {
        HStack(spacing: -2) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(controlBlue)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(35))
                .offset(x: 1, y: 1)

            Image(systemName: "hand.draw.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(controlBlue)
                .rotationEffect(.degrees(-35))
                .offset(x: -1, y: 1)
        }
    }

    private var twoFingerZoomIcon: some View {
        HStack(spacing: -2) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(controlBlue)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(-60))
                .offset(x: 1, y: 1)

            Image(systemName: "hand.draw.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(controlBlue)
                .rotationEffect(.degrees(70))
                .offset(x: -1, y: 1)
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

    private func adjustZoom(by factor: CGFloat) {
        zoom = min(max(zoom * factor, 0.1), 3.0)
    }

    private func adjustSpeed(by delta: Double) {
        logSpeed = min(max(logSpeed + delta, minLogSpeed), maxLogSpeed)
    }

    #if targetEnvironment(macCatalyst)
    private func startMouseControlRepeat(_ action: @escaping () -> Void) {
        guard mouseControlRepeatTask == nil else { return }

        mouseControlRepeatTask = Task { @MainActor in
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    private func stopMouseControlRepeat() {
        mouseControlRepeatTask?.cancel()
        mouseControlRepeatTask = nil
    }
    #endif

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
        .accessibilityLabel(target.displayName(for: currentLanguage))
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
        .accessibilityLabel(FocusTarget.saturn.displayName(for: currentLanguage))
        .accessibilityAddTraits(.isButton)
        .position(pos)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case german
    case english
    case spanish
    case french
    case italian
    case portuguese

    static var systemDefault: AppLanguage {
        let languageCode = Locale.preferredLanguages.first?.prefix(2).lowercased()
        switch languageCode {
        case "en":
            return .english
        case "es":
            return .spanish
        case "fr":
            return .french
        case "it":
            return .italian
        case "pt":
            return .portuguese
        default:
            return .german
        }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "Deutsch"
        case .english:
            return "English"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .italian:
            return "Italiano"
        case .portuguese:
            return "Português"
        }
    }
}

enum LocalizedTextKey {
    case chooseLanguage
    case showGestureHelp
    case gestureControlsTitle
    case panTitle
    case panDetail
    case speedTitle
    case speedDetail
    case zoomTitle
    case zoomDetail
    case focusTitle
    case focusDetail
    case withoutTrackpadTitle
    case withoutTrackpadDetail
    case understood
    case zoomOut
    case zoomIn
    case slowDown
    case speedUp
    case loading

    func text(for language: AppLanguage) -> String {
        switch self {
        case .chooseLanguage:
            switch language {
            case .german: return "Sprache wählen"
            case .english: return "Choose language"
            case .spanish: return "Elegir idioma"
            case .french: return "Choisir la langue"
            case .italian: return "Scegli la lingua"
            case .portuguese: return "Escolher idioma"
            }
        case .showGestureHelp:
            switch language {
            case .german: return "Gestensteuerung anzeigen"
            case .english: return "Show gesture controls"
            case .spanish: return "Mostrar controles de gestos"
            case .french: return "Afficher les gestes"
            case .italian: return "Mostra i gesti"
            case .portuguese: return "Mostrar controles por gestos"
            }
        case .gestureControlsTitle:
            switch language {
            case .german: return "Gestensteuerung"
            case .english: return "Gesture controls"
            case .spanish: return "Controles gestuales"
            case .french: return "Commandes gestuelles"
            case .italian: return "Controlli gestuali"
            case .portuguese: return "Controles por gestos"
            }
        case .panTitle:
            switch language {
            case .german: return "Verschieben"
            case .english: return "Move"
            case .spanish: return "Mover"
            case .french: return "Déplacer"
            case .italian: return "Spostare"
            case .portuguese: return "Mover"
            }
        case .panDetail:
            switch language {
            case .german: return "Mit einem Finger oder Maus ziehen."
            case .english: return "Drag with one finger or the mouse."
            case .spanish: return "Arrastra con un dedo o con el ratón."
            case .french: return "Fais glisser avec un doigt ou la souris."
            case .italian: return "Trascina con un dito o con il mouse."
            case .portuguese: return "Arraste com um dedo ou com o mouse."
            }
        case .speedTitle:
            switch language {
            case .german: return "Geschwindigkeit ändern"
            case .english: return "Change speed"
            case .spanish: return "Cambiar velocidad"
            case .french: return "Changer la vitesse"
            case .italian: return "Cambia velocità"
            case .portuguese: return "Alterar velocidade"
            }
        case .speedDetail:
            switch language {
            case .german: return "Mit zwei Fingern nach oben oder unten ziehen."
            case .english: return "Drag up or down with two fingers."
            case .spanish: return "Arrastra hacia arriba o abajo con dos dedos."
            case .french: return "Fais glisser deux doigts vers le haut ou le bas."
            case .italian: return "Trascina su o giù con due dita."
            case .portuguese: return "Arraste para cima ou para baixo com dois dedos."
            }
        case .zoomTitle:
            switch language {
            case .german: return "Zoom ändern"
            case .english: return "Change zoom"
            case .spanish: return "Cambiar zoom"
            case .french: return "Changer le zoom"
            case .italian: return "Cambia zoom"
            case .portuguese: return "Alterar zoom"
            }
        case .zoomDetail:
            switch language {
            case .german: return "Mit zwei Fingern nach innen oder außen bewegen."
            case .english: return "Move two fingers inward or outward."
            case .spanish: return "Mueve dos dedos hacia dentro o hacia fuera."
            case .french: return "Rapproche ou écarte deux doigts."
            case .italian: return "Avvicina o allontana due dita."
            case .portuguese: return "Aproxime ou afaste dois dedos."
            }
        case .focusTitle:
            switch language {
            case .german: return "Fokus ändern"
            case .english: return "Change focus"
            case .spanish: return "Cambiar enfoque"
            case .french: return "Changer le focus"
            case .italian: return "Cambia focus"
            case .portuguese: return "Alterar foco"
            }
        case .focusDetail:
            switch language {
            case .german: return "Ein Gestirn antippen oder unten einen Namen wählen."
            case .english: return "Tap a body or choose a name below."
            case .spanish: return "Toca un astro o elige un nombre abajo."
            case .french: return "Touche un astre ou choisis un nom en bas."
            case .italian: return "Tocca un astro o scegli un nome in basso."
            case .portuguese: return "Toque em um astro ou escolha um nome abaixo."
            }
        case .withoutTrackpadTitle:
            switch language {
            case .german: return "Ohne Trackpad"
            case .english: return "Without a trackpad"
            case .spanish: return "Sin trackpad"
            case .french: return "Sans trackpad"
            case .italian: return "Senza trackpad"
            case .portuguese: return "Sem trackpad"
            }
        case .withoutTrackpadDetail:
            switch language {
            case .german: return "Die kleinen Maus-Buttons unten ändern Zoom und Geschwindigkeit."
            case .english: return "The small mouse buttons below change zoom and speed."
            case .spanish: return "Los pequeños botones de abajo cambian el zoom y la velocidad."
            case .french: return "Les petits boutons en bas changent le zoom et la vitesse."
            case .italian: return "I piccoli pulsanti in basso cambiano zoom e velocità."
            case .portuguese: return "Os pequenos botões abaixo alteram o zoom e a velocidade."
            }
        case .understood:
            switch language {
            case .german: return "Verstanden"
            case .english: return "Got it"
            case .spanish: return "Entendido"
            case .french: return "Compris"
            case .italian: return "Capito"
            case .portuguese: return "Entendi"
            }
        case .zoomOut:
            switch language {
            case .german: return "Herauszoomen"
            case .english: return "Zoom out"
            case .spanish: return "Alejar"
            case .french: return "Zoom arrière"
            case .italian: return "Riduci zoom"
            case .portuguese: return "Diminuir zoom"
            }
        case .zoomIn:
            switch language {
            case .german: return "Hineinzoomen"
            case .english: return "Zoom in"
            case .spanish: return "Acercar"
            case .french: return "Zoom avant"
            case .italian: return "Aumenta zoom"
            case .portuguese: return "Aumentar zoom"
            }
        case .slowDown:
            switch language {
            case .german: return "Simulation verlangsamen"
            case .english: return "Slow down simulation"
            case .spanish: return "Reducir la velocidad"
            case .french: return "Ralentir la simulation"
            case .italian: return "Rallenta simulazione"
            case .portuguese: return "Reduzir a simulação"
            }
        case .speedUp:
            switch language {
            case .german: return "Simulation beschleunigen"
            case .english: return "Speed up simulation"
            case .spanish: return "Aumentar la velocidad"
            case .french: return "Accélérer la simulation"
            case .italian: return "Accelera simulazione"
            case .portuguese: return "Acelerar a simulação"
            }
        case .loading:
            switch language {
            case .german: return "Lädt ..."
            case .english: return "Loading ..."
            case .spanish: return "Cargando ..."
            case .french: return "Chargement ..."
            case .italian: return "Caricamento ..."
            case .portuguese: return "Carregando ..."
            }
        }
    }
}

extension FocusTarget {
    func displayName(for language: AppLanguage) -> String {
        switch self {
        case .sun:
            switch language {
            case .german: return "Sonne"
            case .english: return "Sun"
            case .spanish: return "Sol"
            case .french: return "Soleil"
            case .italian: return "Sole"
            case .portuguese: return "Sol"
            }
        case .mercury:
            switch language {
            case .german: return "Merkur"
            case .english: return "Mercury"
            case .spanish: return "Mercurio"
            case .french: return "Mercure"
            case .italian: return "Mercurio"
            case .portuguese: return "Mercúrio"
            }
        case .venus:
            switch language {
            case .german: return "Venus"
            case .english: return "Venus"
            case .spanish: return "Venus"
            case .french: return "Vénus"
            case .italian: return "Venere"
            case .portuguese: return "Vênus"
            }
        case .earth:
            switch language {
            case .german: return "Erde"
            case .english: return "Earth"
            case .spanish: return "Tierra"
            case .french: return "Terre"
            case .italian: return "Terra"
            case .portuguese: return "Terra"
            }
        case .moon:
            switch language {
            case .german: return "Mond"
            case .english: return "Moon"
            case .spanish: return "Luna"
            case .french: return "Lune"
            case .italian: return "Luna"
            case .portuguese: return "Lua"
            }
        case .mars:
            switch language {
            case .german: return "Mars"
            case .english: return "Mars"
            case .spanish: return "Marte"
            case .french: return "Mars"
            case .italian: return "Marte"
            case .portuguese: return "Marte"
            }
        case .jupiter:
            switch language {
            case .german: return "Jupiter"
            case .english: return "Jupiter"
            case .spanish: return "Júpiter"
            case .french: return "Jupiter"
            case .italian: return "Giove"
            case .portuguese: return "Júpiter"
            }
        case .saturn:
            switch language {
            case .german: return "Saturn"
            case .english: return "Saturn"
            case .spanish: return "Saturno"
            case .french: return "Saturne"
            case .italian: return "Saturno"
            case .portuguese: return "Saturno"
            }
        case .uranus:
            switch language {
            case .german: return "Uranus"
            case .english: return "Uranus"
            case .spanish: return "Urano"
            case .french: return "Uranus"
            case .italian: return "Urano"
            case .portuguese: return "Urano"
            }
        case .neptune:
            switch language {
            case .german: return "Neptun"
            case .english: return "Neptune"
            case .spanish: return "Neptuno"
            case .french: return "Neptune"
            case .italian: return "Nettuno"
            case .portuguese: return "Netuno"
            }
        }
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

