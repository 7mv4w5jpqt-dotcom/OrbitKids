import SwiftUI
import StoreKit

@main
struct SolarSystemApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await listenForTransactionUpdates()
                }
        }
    }

    private func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            await transaction.finish()
        }
    }
}
