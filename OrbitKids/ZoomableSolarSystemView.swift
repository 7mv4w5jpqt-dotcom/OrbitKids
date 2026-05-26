import SwiftUI
import UIKit

struct ZoomableSolarSystemView<Content: View>: UIViewRepresentable {

    @Binding var zoom: CGFloat
    let content: Content

    init(zoom: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._zoom = zoom
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        // SwiftUI-Content einbetten
        let hosting = UIHostingController(rootView: content)
        context.coordinator.hostingController = hosting
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // UIKit-Pinch-Geste
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        pinch.cancelsTouchesInView = false
        pinch.delaysTouchesBegan = false
        pinch.delaysTouchesEnded = false

        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: $zoom)
    }

    class Coordinator: NSObject {
        @Binding var zoom: CGFloat
        var hostingController: UIHostingController<Content>?
        private var lastScale: CGFloat = 1.0

        init(zoom: Binding<CGFloat>) {
            self._zoom = zoom
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastScale = zoom
            case .changed:
                zoom = min(max(lastScale * gesture.scale, 0.1), 3.0)
            default:
                break
            }
        }
    }
}

