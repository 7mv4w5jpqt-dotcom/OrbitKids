import SwiftUI
import UIKit

enum GestureFeedbackKind: Equatable {
    case pan
    case speedUp
    case speedDown
    case zoomIn
    case zoomOut
    case focus
}

struct ZoomableSolarSystemView<Content: View>: UIViewRepresentable {

    @Binding var zoom: CGFloat
    @Binding var logSpeed: Double
    let minLogSpeed: Double
    let maxLogSpeed: Double

    let onGestureFeedback: (GestureFeedbackKind, CGPoint?) -> Void
    let content: Content

    init(
        zoom: Binding<CGFloat>,
        logSpeed: Binding<Double>,
        minLogSpeed: Double,
        maxLogSpeed: Double,
        onGestureFeedback: @escaping (GestureFeedbackKind, CGPoint?) -> Void = { _, _ in },
        @ViewBuilder content: () -> Content
    ) {
        self._zoom = zoom
        self._logSpeed = logSpeed
        self.minLogSpeed = minLogSpeed
        self.maxLogSpeed = maxLogSpeed
        self.onGestureFeedback = onGestureFeedback
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

        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: Trackpad Pinch → Zoom
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        // Mac Catalyst: Trackpad Scroll → Speed
        let scroll = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleScroll(_:))
        )
        scroll.allowedScrollTypesMask = .continuous
        scroll.delegate = context.coordinator
        view.addGestureRecognizer(scroll)
        #else
        // iOS/iPadOS: Ein gemeinsamer Zwei-Finger-Recognizer klassifiziert Zoom und Speed.
        let twoFingerGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerGesture(_:))
        )
        twoFingerGesture.minimumNumberOfTouches = 2
        twoFingerGesture.maximumNumberOfTouches = 2
        twoFingerGesture.delegate = context.coordinator
        view.addGestureRecognizer(twoFingerGesture)
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
            maxLogSpeed: maxLogSpeed,
            onGestureFeedback: onGestureFeedback
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {

        @Binding var zoom: CGFloat
        @Binding var logSpeed: Double

        let minLogSpeed: Double
        let maxLogSpeed: Double
        let onGestureFeedback: (GestureFeedbackKind, CGPoint?) -> Void

        var hostingController: UIHostingController<Content>?
        private var lastScale: CGFloat = 1.0
        private var lastFeedbackTime: TimeInterval = 0
        private var lastCatalystPinchTime: TimeInterval = 0
        private var isCatalystPinching = false
        private var previousFingerOne: CGPoint?
        private var previousFingerTwo: CGPoint?
        private let twoFingerSpeedThreshold: CGFloat = 3.5
        private let twoFingerZoomThreshold: CGFloat = 1.8
        private let catalystScrollThreshold: CGFloat = 5
        private let catalystScrollAfterPinchDelay: TimeInterval = 0.50

        init(
            zoom: Binding<CGFloat>,
            logSpeed: Binding<Double>,
            minLogSpeed: Double,
            maxLogSpeed: Double,
            onGestureFeedback: @escaping (GestureFeedbackKind, CGPoint?) -> Void
        ) {
            self._zoom = zoom
            self._logSpeed = logSpeed
            self.minLogSpeed = minLogSpeed
            self.maxLogSpeed = maxLogSpeed
            self.onGestureFeedback = onGestureFeedback
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        private func showFeedback(_ kind: GestureFeedbackKind, from gesture: UIGestureRecognizer) {
            let now = CACurrentMediaTime()
            guard now - lastFeedbackTime > 0.18 else { return }
            lastFeedbackTime = now
            onGestureFeedback(kind, gesture.location(in: gesture.view))
        }

        // Pinch → Zoom
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastScale = zoom
                isCatalystPinching = true
                lastCatalystPinchTime = CACurrentMediaTime()
            case .changed:
                zoom = min(max(lastScale * gesture.scale, 0.1), 3.0)
                lastCatalystPinchTime = CACurrentMediaTime()
                showFeedback(gesture.scale >= 1 ? .zoomIn : .zoomOut, from: gesture)
            case .ended, .cancelled, .failed:
                isCatalystPinching = false
                lastCatalystPinchTime = CACurrentMediaTime()
            default:
                break
            }
        }

        // iOS/iPadOS: Zwei Finger parallel → Speed, Abstand ändert sich → Zoom.
        @objc func handleTwoFingerGesture(_ gesture: UIPanGestureRecognizer) {
            #if !targetEnvironment(macCatalyst)
            switch gesture.state {
            case .began, .changed:
                guard gesture.numberOfTouches == 2 else {
                    resetTwoFingerTracking()
                    return
                }

                let fingerOne = gesture.location(ofTouch: 0, in: gesture.view)
                let fingerTwo = gesture.location(ofTouch: 1, in: gesture.view)

                guard let previousFingerOne, let previousFingerTwo else {
                    self.previousFingerOne = fingerOne
                    self.previousFingerTwo = fingerTwo
                    return
                }

                let previousDistance = distance(between: previousFingerOne, and: previousFingerTwo)
                let currentDistance = distance(between: fingerOne, and: fingerTwo)
                let distanceDelta = currentDistance - previousDistance
                let previousMidpoint = midpoint(between: previousFingerOne, and: previousFingerTwo)
                let currentMidpoint = midpoint(between: fingerOne, and: fingerTwo)
                let midpointDeltaY = currentMidpoint.y - previousMidpoint.y
                let fingerOneDelta = CGSize(
                    width: fingerOne.x - previousFingerOne.x,
                    height: fingerOne.y - previousFingerOne.y
                )
                let fingerTwoDelta = CGSize(
                    width: fingerTwo.x - previousFingerTwo.x,
                    height: fingerTwo.y - previousFingerTwo.y
                )

                self.previousFingerOne = fingerOne
                self.previousFingerTwo = fingerTwo

                if abs(distanceDelta) >= twoFingerZoomThreshold && abs(distanceDelta) > abs(midpointDeltaY) * 0.65 {
                    let zoomFactor = max(0.92, min(1.08, currentDistance / max(previousDistance, 1)))
                    zoom = min(max(zoom * zoomFactor, 0.1), 3.0)
                    showFeedback(distanceDelta >= 0 ? .zoomIn : .zoomOut, from: gesture)
                    return
                }

                guard abs(midpointDeltaY) >= twoFingerSpeedThreshold,
                      fingersMoveParallel(fingerOneDelta, fingerTwoDelta),
                      abs(midpointDeltaY) > abs(distanceDelta) * 1.2 else {
                    return
                }

                let change = -Double(midpointDeltaY) * 0.004
                logSpeed = min(max(logSpeed + change, minLogSpeed), maxLogSpeed)
                showFeedback(change >= 0 ? .speedUp : .speedDown, from: gesture)
            case .ended, .cancelled, .failed:
                resetTwoFingerTracking()
            default:
                break
            }
            #endif
        }

        private func resetTwoFingerTracking() {
            previousFingerOne = nil
            previousFingerTwo = nil
        }

        private func distance(between first: CGPoint, and second: CGPoint) -> CGFloat {
            hypot(second.x - first.x, second.y - first.y)
        }

        private func midpoint(between first: CGPoint, and second: CGPoint) -> CGPoint {
            CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        }

        private func fingersMoveParallel(_ first: CGSize, _ second: CGSize) -> Bool {
            let firstLength = hypot(first.width, first.height)
            let secondLength = hypot(second.width, second.height)
            guard firstLength > 0.5, secondLength > 0.5 else { return false }

            let dotProduct = first.width * second.width + first.height * second.height
            return dotProduct / (firstLength * secondLength) > 0.70
        }

        // Mac Catalyst: Trackpad Scroll
        @objc func handleScroll(_ gesture: UIPanGestureRecognizer) {
            #if targetEnvironment(macCatalyst)
            let now = CACurrentMediaTime()
            guard !isCatalystPinching,
                  now - lastCatalystPinchTime > catalystScrollAfterPinchDelay else {
                gesture.setTranslation(.zero, in: gesture.view)
                return
            }

            let dy = gesture.translation(in: gesture.view).y
            guard abs(dy) >= catalystScrollThreshold else { return }

            let change = -Double(dy) * 0.002
            logSpeed = min(max(logSpeed + change, minLogSpeed), maxLogSpeed)
            showFeedback(change >= 0 ? .speedUp : .speedDown, from: gesture)
            gesture.setTranslation(.zero, in: gesture.view)
            #endif
        }
    }
}
