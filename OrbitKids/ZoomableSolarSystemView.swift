import SwiftUI
import UIKit

struct ZoomableSolarSystemView<Content: View>: UIViewRepresentable {

    @Binding var zoom: CGFloat
    @Binding var logSpeed: Double
    let minLogSpeed: Double
    let maxLogSpeed: Double

    let content: Content

    init(
        zoom: Binding<CGFloat>,
        logSpeed: Binding<Double>,
        minLogSpeed: Double,
        maxLogSpeed: Double,
        @ViewBuilder content: () -> Content
    ) {
        self._zoom = zoom
        self._logSpeed = logSpeed
        self.minLogSpeed = minLogSpeed
        self.maxLogSpeed = maxLogSpeed
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

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

        // Pinch (Zoom)
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        // iOS: Zwei-Finger-Speed-Drag
        #if !targetEnvironment(macCatalyst)
        let speedDrag = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSpeedDrag(_:))
        )
        speedDrag.minimumNumberOfTouches = 2
        speedDrag.maximumNumberOfTouches = 2
        speedDrag.delegate = context.coordinator
        view.addGestureRecognizer(speedDrag)
        #endif

        // Mac Catalyst: Trackpad Scroll → Speed
        #if targetEnvironment(macCatalyst)
        let scroll = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleScroll(_:))
        )
        scroll.allowedScrollTypesMask = .continuous
        scroll.delegate = context.coordinator
        view.addGestureRecognizer(scroll)
        #endif

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            zoom: $zoom,
            logSpeed: $logSpeed,
            minLogSpeed: minLogSpeed,
            maxLogSpeed: maxLogSpeed
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {

        @Binding var zoom: CGFloat
        @Binding var logSpeed: Double

        let minLogSpeed: Double
        let maxLogSpeed: Double

        var hostingController: UIHostingController<Content>?
        private var lastScale: CGFloat = 1.0

        init(
            zoom: Binding<CGFloat>,
            logSpeed: Binding<Double>,
            minLogSpeed: Double,
            maxLogSpeed: Double
        ) {
            self._zoom = zoom
            self._logSpeed = logSpeed
            self.minLogSpeed = minLogSpeed
            self.maxLogSpeed = maxLogSpeed
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        // Pinch → Zoom
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

        // iOS: Zwei-Finger-Speed-Drag
        @objc func handleSpeedDrag(_ gesture: UIPanGestureRecognizer) {
            #if !targetEnvironment(macCatalyst)
            let deltaY = gesture.translation(in: gesture.view).y
            let change = -Double(deltaY) * 0.004
            logSpeed = min(max(logSpeed + change, minLogSpeed), maxLogSpeed)
            gesture.setTranslation(.zero, in: gesture.view)
            #endif
        }

        // Mac Catalyst: Trackpad Scroll
        @objc func handleScroll(_ gesture: UIPanGestureRecognizer) {
            #if targetEnvironment(macCatalyst)
            let dy = gesture.translation(in: gesture.view).y
            let change = -Double(dy) * 0.002
            logSpeed = min(max(logSpeed + change, minLogSpeed), maxLogSpeed)
            gesture.setTranslation(.zero, in: gesture.view)
            #endif
        }
    }
}

