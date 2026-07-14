import SwiftUI
import Combine
import UIKit

final class DisplayLinkDriver: ObservableObject {
    @Published var phase: CGFloat = 0
    private var link: CADisplayLink?

    init() {
        link = CADisplayLink(target: self, selector: #selector(update))
        link?.add(to: .main, forMode: .common)
    }

    @objc private func update() {
        let t = Date().timeIntervalSinceReferenceDate
        let speed: CGFloat = 0.6
        phase = CGFloat(t * Double(speed)).truncatingRemainder(dividingBy: 1)
    }

    deinit {
        link?.invalidate()
    }
}


private func appIconImage() -> Image {
    if let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
       let primaryIconsDict = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
       let iconFiles = primaryIconsDict["CFBundleIconFiles"] as? [String],
       let lastIcon = iconFiles.last,
       let uiImage = UIImage(named: lastIcon) {
        return Image(uiImage: uiImage)
    }
    if let img = UIImage(named: "AppIconLarge") {
        return Image(uiImage: img)
    }
    return Image(systemName: "app.fill")
}

// Simple app readiness gate
enum AppPhase: Equatable {
    case loading
    case ready
    case error(String)
}

@Observable
final class AppState {
    private var isPreparing = false
    private let hasLaunchedKey = "hasLaunchedBefore"
    var phase: AppPhase = .loading

    // Call this on app start to prepare resources and stabilize state
    func prepare() async {
        if isPreparing || phase == .ready { return }
        isPreparing = true

        print("[AppState] prepare() start")

        let firstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        let minimumDisplay: UInt64 = firstLaunch ? 8_000_000_000 : 5_000_000_000 // 8s first launch, 5s afterwards

        do {
            // Start minimum display timer and real prep concurrently
            async let minDelay: Void = Task.sleep(nanoseconds: minimumDisplay)

            // TODO: Insert real preparation here.
            // Example skeleton:
            // try await preloadAssets()
            // try await warmUpPipelines()
            // try await loadEphemerides()
            // normalizeInitialState()
            try await Task.sleep(nanoseconds: 300_000_000) // simulate work

            // Wait for both the minimum display duration and the work to complete
            _ = try await (minDelay)

            print("[AppState] prepare() end -> ready")
            await MainActor.run { self.phase = .ready }
            if firstLaunch {
                UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            }
        } catch {
            print("[AppState] prepare() end -> error: \(error.localizedDescription)")
            await MainActor.run { self.phase = .error("Vorbereitung fehlgeschlagen: \(error.localizedDescription)") }
        }

        isPreparing = false
    }
}

struct LoadingView: View {
    @StateObject private var driver = DisplayLinkDriver()
    @AppStorage("selectedLanguage") private var selectedLanguageRawValue = AppLanguage.systemDefault.rawValue

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageRawValue) ?? .systemDefault
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack {
                Spacer(minLength: 0)
                VStack(spacing: 16) {
                    appIconImage()
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .white.opacity(0.08), radius: 8, y: 4)

                    Text(LocalizedTextKey.loading.text(for: currentLanguage))
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }

            SweepingBarLayerView()
                .frame(height: 14)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
    }
}



private struct SweepingBar: View {
    var phase: CGFloat // 0..1

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let gradientWidth = width * 0.35
            let offset = -width + (1 - phase) * (width + gradientWidth)

            ZStack(alignment: .leading) {
                // Base bar
                LinearGradient(colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.10)
                ], startPoint: .leading, endPoint: .trailing)

                // Moving bright sweep
                LinearGradient(gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(0.35), location: 0.5),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ]), startPoint: .leading, endPoint: .trailing)
                .frame(width: gradientWidth)
                .offset(x: offset)
            }
        }
    }
}

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                LoadingView()
            case .ready:
                SolarSystemView()
                    .background(Color.black)
                    .ignoresSafeArea()
            case .error(let message):
                VStack(spacing: 12) {
                    Text("Fehler beim Start")
                        .font(.title3)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Erneut versuchen") {
                        Task { await appState.prepare() }
                    }
                }
                .padding()
            }
        }
        .task { await appState.prepare() }
    }
}

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
