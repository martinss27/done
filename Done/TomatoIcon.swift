import SwiftUI

/// SF Symbols has no tomato, so we draw one: a round body under a leafy crown.
struct TomatoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.addEllipse(in: CGRect(x: w * 0.04, y: h * 0.26, width: w * 0.92, height: h * 0.72))

        let stem = CGPoint(x: w / 2, y: h * 0.32)
        var leaf = Path()
        leaf.move(to: stem)
        leaf.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.02), control: CGPoint(x: w * 0.95, y: h * 0.05))
        leaf.addQuadCurve(to: stem, control: CGPoint(x: w * 0.60, y: h * 0.16))
        for degrees in [-58.0, 0.0, 58.0] {
            let spin = CGAffineTransform(translationX: stem.x, y: stem.y)
                .rotated(by: degrees * .pi / 180)
                .translatedBy(x: -stem.x, y: -stem.y)
            p.addPath(leaf.applying(spin))
        }
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// The tab bar takes an Image, not a view, so render the shape once as a
/// template so it tints like every other symbol next to it.
@MainActor let tomatoSymbol: Image = {
    let renderer = ImageRenderer(content: TomatoShape().frame(width: 26, height: 26).foregroundStyle(.black))
    renderer.scale = 3
    let image = renderer.uiImage ?? UIImage()
    return Image(uiImage: image.withRenderingMode(.alwaysTemplate))
}()
