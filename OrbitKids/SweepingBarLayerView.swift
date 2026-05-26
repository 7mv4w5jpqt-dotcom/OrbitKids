import SwiftUI
import UIKit

struct SweepingBarLayerView: UIViewRepresentable {

    func makeUIView(context: Context) -> BarView {
        BarView()
    }

    func updateUIView(_ uiView: BarView, context: Context) {}
}

final class BarView: UIView {

    private let baseLayer = CALayer()
    private let sweepLayer = CAGradientLayer()
    private var animationAdded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        // Grundbalken
        baseLayer.backgroundColor = UIColor.white.withAlphaComponent(0.10).cgColor
        layer.addSublayer(baseLayer)

        // Sweep
        sweepLayer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.35).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        sweepLayer.startPoint = CGPoint(x: 0, y: 0.5)
        sweepLayer.endPoint = CGPoint(x: 1, y: 0.5)
        sweepLayer.locations = [0, 0.5, 1]
        layer.addSublayer(sweepLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let h = bounds.height
        let sweepWidth = w * 0.35

        baseLayer.frame = bounds
        sweepLayer.frame = CGRect(x: -sweepWidth, y: 0, width: sweepWidth, height: h)

        // Animation erst starten, wenn die Größe feststeht
        if !animationAdded && w > 0 {
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = -sweepWidth
            anim.toValue = w + sweepWidth
            anim.duration = 1.2
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .linear)
            sweepLayer.add(anim, forKey: "sweep")
            animationAdded = true
        }
    }
}

