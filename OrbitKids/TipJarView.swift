import SwiftUI
import StoreKit

struct TipJarView: View {
    let language: AppLanguage
    let onClose: () -> Void

    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var purchaseState: TipPurchaseState?
    @State private var purchasingProductID: String?

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
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .success
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

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitVerificationError.failed
        }
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
            case .german: return "Entwickler unterstützen 🚀"
            case .english: return "Support the Developer 🚀"
            case .spanish: return "Apoyar al desarrollador 🚀"
            case .french: return "Soutenir le développeur 🚀"
            case .italian: return "Sostieni lo sviluppatore 🚀"
            case .portuguese: return "Apoiar o desenvolvedor 🚀"
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
            case .german: return "Danke für deine Unterstützung! 🌟"
            case .english: return "Thank you for your support! 🌟"
            case .spanish: return "¡Gracias por tu apoyo! 🌟"
            case .french: return "Merci pour ton soutien ! 🌟"
            case .italian: return "Grazie per il tuo supporto! 🌟"
            case .portuguese: return "Obrigado pelo apoio! 🌟"
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
