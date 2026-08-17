import SwiftUI
import StoreKit

struct TipJarView: View {
    let language: AppLanguage
    let onClose: () -> Void

    @Environment(\.purchase) private var purchaseAction

    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var purchaseState: TipPurchaseState?
    @State private var purchasingProductID: String?
    @State private var showCelebration = false

    private let productIDs = [
        "orbitkids.tip.small",
        "orbitkids.tip.medium",
        "orbitkids.tip.large"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TipJarText.title.text(for: language))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(TipJarText.subtitle.text(for: language))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TipJarText.close.text(for: language))
                }

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else if products.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(TipJarText.productsUnavailable.text(for: language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(productIDs.joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                } else {
                    HStack(spacing: 14) {
                        ForEach(products, id: \.id) { product in
                            tipButton(for: product)
                        }
                    }
                }

                if let purchaseState {
                    Text(purchaseState.message(for: language))
                        .font(.footnote)
                        .foregroundStyle(purchaseState.isError ? Color.red.opacity(0.92) : Color.white.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(22)
            .frame(maxWidth: 430)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.18, green: 0.45, blue: 0.90).opacity(0.42), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)

            if showCelebration {
                TipCelebrationView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .task {
            await loadProducts()
        }
    }

    private func tipButton(for product: Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            VStack(spacing: 5) {
                if purchasingProductID == product.id {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 28)
                } else {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(product.displayName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 82)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchasingProductID != nil)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice)")
    }

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: productIDs)
            products = loadedProducts.sorted { first, second in
                let firstIndex = productIDs.firstIndex(of: first.id) ?? Int.max
                let secondIndex = productIDs.firstIndex(of: second.id) ?? Int.max
                return firstIndex < secondIndex
            }
        } catch {
            purchaseState = .failed
            products = []
        }
    }

    private func purchase(_ product: Product) async {
        purchasingProductID = product.id
        purchaseState = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await purchaseAction(product)

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .success
                showPurchaseCelebration()
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = nil
            @unknown default:
                purchaseState = .failed
            }
        } catch {
            purchaseState = .failed
        }
    }

    private func showPurchaseCelebration() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showCelebration = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                showCelebration = false
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitVerificationError.failed
        }
    }
}

private struct TipCelebrationView: View {
    @State private var fireworkFlightProgress: CGFloat = 0
    @State private var explosionsStarted = false
    @State private var particlesFalling = false

    private let flightDuration: TimeInterval = 1.72
    private let explosionDelay: TimeInterval = 1.65
    private let launchStagger: TimeInterval = 0.13

    private let explosionOffsets = [
        CGSize(width: -126, height: 26),
        CGSize(width: 0, height: -18),
        CGSize(width: 126, height: 30)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<explosionOffsets.count, id: \.self) { index in
                    let launchPoint = CGPoint(x: geo.size.width / 2, y: geo.size.height + 34)
                    let x = geo.size.width / 2 + explosionOffsets[index].width
                    let y = geo.size.height * 0.32 + explosionOffsets[index].height
                    let center = CGPoint(x: x, y: y)
                    let flightEnd = CGPoint(x: x, y: y + 26)

                    TipFireworkLightView(
                        start: launchPoint,
                        end: flightEnd,
                        progress: fireworkFlightProgress,
                        isHidden: explosionsStarted,
                        flightDuration: flightDuration,
                        delay: Double(index) * launchStagger
                    )

                    TipExplosionView(
                        center: center,
                        index: index,
                        color: explosionColor(for: index),
                        isWhiteBurst: index == 1,
                        isVisible: explosionsStarted,
                        isFalling: particlesFalling
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task {
            withAnimation(.linear(duration: flightDuration)) {
                fireworkFlightProgress = 1
            }

            try? await Task.sleep(nanoseconds: UInt64(explosionDelay * 1_000_000_000))

            explosionsStarted = true

            try? await Task.sleep(nanoseconds: 220_000_000)

            withAnimation(.easeIn(duration: 2.25)) {
                particlesFalling = true
            }
        }
    }

    private func explosionColor(for index: Int) -> Color {
        switch index {
        case 0:
            return .blue
        case 1:
            return .white
        default:
            return .red
        }
    }
}

private struct TipFireworkLightView: View, Animatable {
    let start: CGPoint
    let end: CGPoint
    var progress: CGFloat
    let isHidden: Bool
    let flightDuration: TimeInterval
    let delay: TimeInterval

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 4, height: 4)
            .shadow(color: .white, radius: 6)
            .position(currentPosition)
            .opacity(isHidden ? 0 : 1)
            .animation(.easeOut(duration: 0.12), value: isHidden)
    }

    private var currentPosition: CGPoint {
        let delayProgress = CGFloat(delay / flightDuration)
        let delayedProgress = max(0, min(1, (progress - delayProgress) / (1 - delayProgress)))
        let gravity = gravityForTrajectory(apexTime: 0.76)
        let initialVelocityY = -2 * gravity * 0.76
        let x = start.x + (end.x - start.x) * delayedProgress
        let y = start.y + initialVelocityY * delayedProgress + gravity * delayedProgress * delayedProgress
        return CGPoint(x: x, y: y)
    }

    private func gravityForTrajectory(apexTime: CGFloat) -> CGFloat {
        (end.y - start.y) / (1 - 2 * apexTime)
    }
}

private struct TipExplosionView: View {
    let center: CGPoint
    let index: Int
    let color: Color
    let isWhiteBurst: Bool
    let isVisible: Bool
    let isFalling: Bool

    var body: some View {
        ZStack {
            ForEach(0..<84, id: \.self) { particle in
                TipFireworkParticle(
                    particle: particle,
                    burstIndex: index,
                    color: color,
                    highlightOpacity: isWhiteBurst ? 0.65 : 0.24,
                    isVisible: isVisible,
                    isFalling: isFalling
                )
            }

            Circle()
                .fill(color.opacity(0.32))
                .frame(width: isVisible ? 18 : 4, height: isVisible ? 18 : 4)
                .blur(radius: 7)
                .opacity(isVisible ? (isFalling ? 0 : 1) : 0)
                .animation(.easeOut(duration: 0.26), value: isVisible)
                .animation(.easeOut(duration: 0.9), value: isFalling)
        }
        .position(center)
    }
}

private struct TipFireworkParticle: View {
    let particle: Int
    let burstIndex: Int
    let color: Color
    let highlightOpacity: Double
    let isVisible: Bool
    let isFalling: Bool

    private var angle: CGFloat {
        randomUnit(seed: 11) * .pi * 2
    }

    private var burstRadius: CGFloat {
        let nearCore = randomUnit(seed: 23) * randomUnit(seed: 37)
        return 8 + nearCore * 82
    }

    private var fallDistance: CGFloat {
        96 + randomUnit(seed: 53) * 136
    }

    private var drift: CGFloat {
        (randomUnit(seed: 71) - 0.5) * 48
    }

    private var particleOpacity: Double {
        0.42 + Double(randomUnit(seed: 89)) * 0.58
    }

    var body: some View {
        Circle()
            .fill(color.opacity(particleOpacity))
            .frame(width: particleSize, height: particleSize)
            .shadow(color: color.opacity(0.85), radius: 2.5)
            .overlay(
                Circle()
                    .fill(.white.opacity(highlightOpacity * particleOpacity))
                    .frame(width: max(1, particleSize * 0.38), height: max(1, particleSize * 0.38))
            )
            .offset(
                x: xOffset,
                y: yOffset
            )
            .opacity(isVisible ? (isFalling ? 0 : particleOpacity) : 0)
            .animation(.easeOut(duration: 0.46).delay(Double(randomUnit(seed: 101)) * 0.08), value: isVisible)
            .animation(.easeIn(duration: 2.35).delay(Double(randomUnit(seed: 113)) * 0.16), value: isFalling)
    }

    private var particleSize: CGFloat {
        1.6 + randomUnit(seed: 131) * 3.2
    }

    private var xOffset: CGFloat {
        let burstX = cos(angle) * burstRadius
        return isFalling ? burstX + drift : (isVisible ? burstX : 0)
    }

    private var yOffset: CGFloat {
        let burstY = sin(angle) * burstRadius
        return isFalling ? burstY + fallDistance : (isVisible ? burstY : 0)
    }

    private func randomUnit(seed: Int) -> CGFloat {
        let value = sin(Double((particle + 1) * (burstIndex + 3) * seed)) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

private enum StoreKitVerificationError: Error {
    case failed
}

private enum TipPurchaseState {
    case success
    case pending
    case failed

    var isError: Bool {
        if case .failed = self { return true }
        return false
    }

    func message(for language: AppLanguage) -> String {
        switch self {
        case .success:
            return TipJarText.thankYou.text(for: language)
        case .pending:
            return TipJarText.pending.text(for: language)
        case .failed:
            return TipJarText.failed.text(for: language)
        }
    }
}

enum TipJarText {
    case title
    case subtitle
    case tipButton
    case close
    case productsUnavailable
    case thankYou
    case pending
    case failed

    func text(for language: AppLanguage) -> String {
        switch self {
        case .title:
            switch language {
            case .german: return "Entwickler unterstützen ✨"
            case .english: return "Support the Developer ✨"
            case .spanish: return "Apoyar al desarrollador ✨"
            case .french: return "Soutenir le développeur ✨"
            case .italian: return "Sostieni lo sviluppatore ✨"
            case .portuguese: return "Apoiar o desenvolvedor ✨"
            }
        case .subtitle:
            switch language {
            case .german: return "Wenn dir OrbitKids gefällt, kannst du den Entwickler mit einem kleinen Beitrag unterstützen. ❤️"
            case .english: return "If you like OrbitKids, you can support the developer with a small contribution. ❤️"
            case .spanish: return "Si te gusta OrbitKids, puedes apoyar al desarrollador con una pequeña contribución. ❤️"
            case .french: return "Si tu aimes OrbitKids, tu peux soutenir le développeur avec une petite contribution. ❤️"
            case .italian: return "Se ti piace OrbitKids, puoi sostenere lo sviluppatore con un piccolo contributo. ❤️"
            case .portuguese: return "Se você gosta do OrbitKids, pode apoiar o desenvolvedor com uma pequena contribuição. ❤️"
            }
        case .tipButton:
            switch language {
            case .german: return "Unterstützen 💫"
            case .english: return "Support 💫"
            case .spanish: return "Apoyar 💫"
            case .french: return "Soutenir 💫"
            case .italian: return "Sostieni 💫"
            case .portuguese: return "Apoiar 💫"
            }
        case .close:
            switch language {
            case .german: return "Schließen"
            case .english: return "Close"
            case .spanish: return "Cerrar"
            case .french: return "Fermer"
            case .italian: return "Chiudi"
            case .portuguese: return "Fechar"
            }
        case .productsUnavailable:
            switch language {
            case .german: return "Tip-Produkte sind noch nicht verfügbar. Lege diese Consumable In-App Purchases in App Store Connect an:"
            case .english: return "Tip products are not available yet. Create these consumable In-App Purchases in App Store Connect:"
            case .spanish: return "Los productos de propina aún no están disponibles. Crea estas compras consumibles en App Store Connect:"
            case .french: return "Les produits de soutien ne sont pas encore disponibles. Crée ces achats intégrés consommables dans App Store Connect :"
            case .italian: return "I prodotti per la mancia non sono ancora disponibili. Crea questi acquisti in-app consumabili in App Store Connect:"
            case .portuguese: return "Os produtos de gorjeta ainda não estão disponíveis. Crie estas compras consumíveis no App Store Connect:"
            }
        case .thankYou:
            switch language {
            case .german: return "Herzlichen Dank für deine Unterstützung! 🌟"
            case .english: return "Many heartfelt thanks for your support! 🌟"
            case .spanish: return "¡Muchísimas gracias por tu apoyo! 🌟"
            case .french: return "Un grand merci pour ton soutien ! 🌟"
            case .italian: return "Grazie di cuore per il tuo supporto! 🌟"
            case .portuguese: return "Muito obrigado pelo apoio! 🌟"
            }
        case .pending:
            switch language {
            case .german: return "Der Kauf wartet auf Bestätigung."
            case .english: return "The purchase is waiting for approval."
            case .spanish: return "La compra está esperando aprobación."
            case .french: return "L’achat attend une approbation."
            case .italian: return "L’acquisto è in attesa di approvazione."
            case .portuguese: return "A compra está aguardando aprovação."
            }
        case .failed:
            switch language {
            case .german: return "Der Kauf konnte nicht abgeschlossen werden."
            case .english: return "The purchase could not be completed."
            case .spanish: return "No se pudo completar la compra."
            case .french: return "L’achat n’a pas pu être terminé."
            case .italian: return "Non è stato possibile completare l’acquisto."
            case .portuguese: return "Não foi possível concluir a compra."
            }
        }
    }
}
