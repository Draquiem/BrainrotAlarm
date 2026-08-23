import SwiftUI

/// Draws a `CreatureRecipe` into a square, in one `Canvas` pass.
///
/// Everything is laid out in a 0...1 unit square and scaled at draw time, so the
/// same code serves a 44 pt list thumbnail and a full-screen answer tile.
struct CreatureView: View {
    let recipe: CreatureRecipe
    /// Character id. When artwork for it has been dropped into `Assets/images/`,
    /// that image is used and the procedural drawing is skipped entirely.
    var assetID: String?
    var showsBackdrop: Bool = true

    var body: some View {
        if let assetID, let artwork = AssetLibrary.image(for: assetID) {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .accessibilityHidden(true)
        } else {
            drawn
        }
    }

    private var drawn: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                if showsBackdrop {
                    recipe.palette.backdrop
                }
                Canvas { context, size in
                    let inset = side * 0.06
                    let square = CGRect(
                        x: (size.width - side) / 2 + inset,
                        y: (size.height - side) / 2 + inset,
                        width: side - inset * 2,
                        height: side - inset * 2)
                    if recipe.tilt != 0 {
                        let pivot = CGPoint(x: size.width / 2, y: size.height / 2)
                        context.translateBy(x: pivot.x, y: pivot.y)
                        context.rotate(by: .degrees(recipe.tilt))
                        context.translateBy(x: -pivot.x, y: -pivot.y)
                    }
                    CreatureRenderer(recipe: recipe).draw(in: &context, rect: square)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The actual drawing. Split out of the view so it stays readable and so a
/// preview or a test can call it directly.
struct CreatureRenderer {
    let recipe: CreatureRecipe

    private var palette: Palette { recipe.palette }

    // MARK: - Anatomy

    /// Where the parts sit, in unit coordinates.
    fileprivate struct Anatomy {
        var body: CGRect
        var headCenter: CGPoint
        var headRadius: CGFloat
        var faceCenter: CGPoint
        var faceScale: CGFloat
    }

    private func anatomy() -> Anatomy {
        let chonk = recipe.chonk
        var body: CGRect
        switch recipe.body {
        case .blob:     body = CGRect(x: 0.16, y: 0.40, width: 0.68, height: 0.50)
        case .pear:     body = CGRect(x: 0.20, y: 0.38, width: 0.60, height: 0.54)
        case .tall:     body = CGRect(x: 0.29, y: 0.30, width: 0.42, height: 0.62)
        case .wide:     body = CGRect(x: 0.12, y: 0.46, width: 0.76, height: 0.38)
        case .fruit:    body = CGRect(x: 0.23, y: 0.34, width: 0.54, height: 0.56)
        case .cup:      body = CGRect(x: 0.26, y: 0.40, width: 0.48, height: 0.48)
        case .log:      body = CGRect(x: 0.32, y: 0.20, width: 0.36, height: 0.72)
        case .fuselage: body = CGRect(x: 0.15, y: 0.44, width: 0.70, height: 0.34)
        }
        if chonk != 1 {
            let dx = body.width * (chonk - 1) / 2
            body = body.insetBy(dx: -dx, dy: 0)
        }

        if recipe.head == .merged {
            // Face rides high on the body itself.
            let center = CGPoint(x: body.midX, y: body.minY + body.height * 0.34)
            return Anatomy(body: body, headCenter: center, headRadius: 0,
                           faceCenter: center, faceScale: min(body.width, body.height) * 0.9)
        }

        let radius: CGFloat = recipe.head == .wedge ? 0.19 : 0.165
        // Quadrupeds carry the head off to one side; everything else stacks it on top.
        let center = recipe.body == .wide
            ? CGPoint(x: body.minX + 0.10, y: body.minY - 0.02)
            : CGPoint(x: body.midX, y: body.minY - radius * 0.55)
        return Anatomy(body: body, headCenter: center, headRadius: radius,
                       faceCenter: CGPoint(x: center.x, y: center.y + radius * 0.12),
                       faceScale: radius * 2)
    }

    // MARK: - Entry

    func draw(in context: inout GraphicsContext, rect: CGRect) {
        let a = anatomy()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        func s(_ v: CGFloat) -> CGFloat { v * rect.width }
        let g = Geometry(point: p, scale: s)

        drawBackProps(&context, g, a)
        drawLimbs(&context, g, a)

        let bodyPath = bodyPath(g, a)
        context.fill(bodyPath, with: .linearGradient(
            Gradient(colors: [palette.bodyColor, palette.shadeColor]),
            startPoint: g.point(0.3, 0.2), endPoint: g.point(0.8, 1.0)))
        drawPattern(&context, g, a, clippedTo: bodyPath)
        context.stroke(bodyPath, with: .color(Palette.ink.opacity(0.55)), lineWidth: g.scale(0.012))

        drawEars(&context, g, a)
        if recipe.head != .merged { drawHead(&context, g, a) }
        drawEyes(&context, g, a)
        drawMouth(&context, g, a)
        drawFrontProps(&context, g, a)
    }

    /// Bundles the unit-to-pixel conversions so the part functions stay short.
    fileprivate struct Geometry {
        let point: (CGFloat, CGFloat) -> CGPoint
        let scale: (CGFloat) -> CGFloat
    }

    // MARK: - Body

    private func bodyPath(_ g: Geometry, _ a: Anatomy) -> Path {
        let r = a.body
        var path = Path()
        switch recipe.body {
        case .blob, .fruit:
            path.addEllipse(in: rect(g, r))
        case .pear:
            let top = g.point(r.midX, r.minY)
            let bottomLeft = g.point(r.minX, r.maxY - r.height * 0.18)
            let bottomRight = g.point(r.maxX, r.maxY - r.height * 0.18)
            path.move(to: top)
            path.addQuadCurve(to: bottomRight,
                              control: g.point(r.maxX + 0.02, r.minY + r.height * 0.45))
            path.addQuadCurve(to: g.point(r.midX, r.maxY),
                              control: g.point(r.maxX - r.width * 0.1, r.maxY))
            path.addQuadCurve(to: bottomLeft,
                              control: g.point(r.minX + r.width * 0.1, r.maxY))
            path.addQuadCurve(to: top,
                              control: g.point(r.minX - 0.02, r.minY + r.height * 0.45))
        case .tall, .wide:
            path.addRoundedRect(in: rect(g, r),
                                cornerSize: CGSize(width: g.scale(min(r.width, r.height) * 0.48),
                                                   height: g.scale(min(r.width, r.height) * 0.48)))
        case .cup:
            path.move(to: g.point(r.minX, r.minY))
            path.addLine(to: g.point(r.maxX, r.minY))
            path.addLine(to: g.point(r.maxX - r.width * 0.16, r.maxY))
            path.addQuadCurve(to: g.point(r.minX + r.width * 0.16, r.maxY),
                              control: g.point(r.midX, r.maxY + 0.03))
            path.closeSubpath()
        case .log:
            path.addRoundedRect(in: rect(g, r),
                                cornerSize: CGSize(width: g.scale(r.width * 0.30),
                                                   height: g.scale(r.width * 0.30)))
        case .fuselage:
            path.move(to: g.point(r.maxX, r.midY))
            path.addQuadCurve(to: g.point(r.minX + r.width * 0.12, r.minY),
                              control: g.point(r.maxX - r.width * 0.35, r.minY - 0.02))
            path.addQuadCurve(to: g.point(r.minX, r.midY),
                              control: g.point(r.minX - 0.02, r.minY + r.height * 0.3))
            path.addQuadCurve(to: g.point(r.minX + r.width * 0.12, r.maxY),
                              control: g.point(r.minX - 0.02, r.maxY - r.height * 0.3))
            path.addQuadCurve(to: g.point(r.maxX, r.midY),
                              control: g.point(r.maxX - r.width * 0.35, r.maxY + 0.02))
        }
        return path
    }

    private func rect(_ g: Geometry, _ r: CGRect) -> CGRect {
        let origin = g.point(r.minX, r.minY)
        let corner = g.point(r.maxX, r.maxY)
        return CGRect(x: origin.x, y: origin.y, width: corner.x - origin.x, height: corner.y - origin.y)
    }

    // MARK: - Pattern

    private func drawPattern(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy, clippedTo body: Path) {
        guard recipe.pattern != .none else { return }
        var layer = context
        layer.clip(to: body)
        let r = a.body
        let ink = palette.shadeColor.opacity(0.55)

        switch recipe.pattern {
        case .none:
            break
        case .stripes:
            var i = 0.0
            while i < 1 {
                var bar = Path()
                let x = r.minX + r.width * i
                bar.addRect(CGRect(x: g.point(x, r.minY).x, y: g.point(x, r.minY).y,
                                   width: g.scale(r.width * 0.075), height: g.scale(r.height)))
                layer.fill(bar, with: .color(ink))
                i += 0.19
            }
        case .spots:
            let spots: [(CGFloat, CGFloat, CGFloat)] = [
                (0.28, 0.30, 0.10), (0.62, 0.22, 0.07), (0.44, 0.62, 0.09),
                (0.75, 0.58, 0.06), (0.20, 0.72, 0.06)]
            for (sx, sy, sr) in spots {
                var dot = Path()
                let center = g.point(r.minX + r.width * sx, r.minY + r.height * sy)
                let radius = g.scale(r.width * sr)
                dot.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
                layer.fill(dot, with: .color(ink))
            }
        case .scales:
            var row = 0
            var y = r.minY
            while y < r.maxY {
                var x = r.minX + (row.isMultiple(of: 2) ? 0 : r.width * 0.07)
                while x < r.maxX {
                    var arc = Path()
                    let box = CGRect(x: g.point(x, y).x, y: g.point(x, y).y,
                                     width: g.scale(r.width * 0.15), height: g.scale(r.height * 0.16))
                    arc.addArc(center: CGPoint(x: box.midX, y: box.minY),
                               radius: box.width / 2, startAngle: .degrees(0),
                               endAngle: .degrees(180), clockwise: false)
                    layer.stroke(arc, with: .color(ink), lineWidth: g.scale(0.008))
                    x += r.width * 0.14
                }
                y += r.height * 0.13
                row += 1
            }
        case .checker:
            var row = 0
            var y = r.minY
            while y < r.maxY {
                var col = 0
                var x = r.minX
                while x < r.maxX {
                    if (row + col).isMultiple(of: 2) {
                        var square = Path()
                        square.addRect(CGRect(x: g.point(x, y).x, y: g.point(x, y).y,
                                              width: g.scale(r.width * 0.17),
                                              height: g.scale(r.height * 0.15)))
                        layer.fill(square, with: .color(ink))
                    }
                    x += r.width * 0.17; col += 1
                }
                y += r.height * 0.15; row += 1
            }
        case .swirl:
            var spiral = Path()
            let center = g.point(r.midX, r.midY)
            var radius = g.scale(r.width * 0.06)
            var angle = 0.0
            spiral.move(to: center)
            while radius < g.scale(r.width * 0.5) {
                angle += 0.35
                radius += g.scale(r.width * 0.012)
                spiral.addLine(to: CGPoint(x: center.x + cos(angle) * radius,
                                           y: center.y + sin(angle) * radius))
            }
            layer.stroke(spiral, with: .color(ink), lineWidth: g.scale(0.014))
        }
    }
}

// MARK: - Head, face and limbs

extension CreatureRenderer {

    private func circle(_ g: Geometry, _ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat) -> Path {
        let center = g.point(cx, cy)
        let r = g.scale(radius)
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    private func outline(_ g: Geometry) -> (Color, CGFloat) {
        (Palette.ink.opacity(0.55), g.scale(0.012))
    }

    fileprivate func drawHead(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let c = a.headCenter
        let r = a.headRadius
        let (ink, width) = outline(g)
        var path = Path()

        switch recipe.head {
        case .merged:
            return
        case .round:
            path = circle(g, c.x, c.y, r)
        case .snout:
            path = circle(g, c.x, c.y, r)
            // Muzzle pushed forward and down.
            path.addPath(circle(g, c.x + r * 0.05, c.y + r * 0.45, r * 0.62))
        case .wedge:
            path.move(to: g.point(c.x - r * 1.15, c.y - r * 0.35))
            path.addQuadCurve(to: g.point(c.x + r * 1.2, c.y + r * 0.1),
                              control: g.point(c.x, c.y - r * 1.05))
            path.addQuadCurve(to: g.point(c.x - r * 1.15, c.y + r * 0.75),
                              control: g.point(c.x, c.y + r * 1.0))
            path.closeSubpath()
        case .beak:
            path = circle(g, c.x, c.y, r * 0.92)
        case .box:
            let box = CGRect(x: g.point(c.x - r, c.y - r).x, y: g.point(c.x - r, c.y - r).y,
                             width: g.scale(r * 2), height: g.scale(r * 2))
            path.addRoundedRect(in: box, cornerSize: CGSize(width: g.scale(r * 0.3),
                                                            height: g.scale(r * 0.3)))
        }

        context.fill(path, with: .linearGradient(
            Gradient(colors: [palette.bodyColor, palette.shadeColor]),
            startPoint: g.point(c.x - r, c.y - r), endPoint: g.point(c.x + r, c.y + r)))
        context.stroke(path, with: .color(ink), lineWidth: width)

        if recipe.head == .beak {
            var beak = Path()
            beak.move(to: g.point(c.x + r * 0.75, c.y - r * 0.12))
            beak.addLine(to: g.point(c.x + r * 1.7, c.y + r * 0.14))
            beak.addLine(to: g.point(c.x + r * 0.75, c.y + r * 0.42))
            beak.closeSubpath()
            context.fill(beak, with: .color(palette.accentColor))
            context.stroke(beak, with: .color(ink), lineWidth: width)
        }
    }

    fileprivate func drawEars(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let c = a.headCenter
        let r = max(a.headRadius, 0.14)
        let (ink, width) = outline(g)
        let fill = GraphicsContext.Shading.color(palette.shadeColor)

        func mirrored(_ build: (CGFloat) -> Path) {
            for side in [CGFloat(-1), 1] {
                let path = build(side)
                context.fill(path, with: fill)
                context.stroke(path, with: .color(ink), lineWidth: width)
            }
        }

        switch recipe.ears {
        case .none:
            break
        case .round:
            mirrored { side in circle(g, c.x + side * r * 0.82, c.y - r * 0.62, r * 0.36) }
        case .pointy:
            mirrored { side in
                var p = Path()
                p.move(to: g.point(c.x + side * r * 0.28, c.y - r * 0.80))
                p.addLine(to: g.point(c.x + side * r * 0.92, c.y - r * 1.45))
                p.addLine(to: g.point(c.x + side * r * 1.00, c.y - r * 0.52))
                p.closeSubpath()
                return p
            }
        case .floppy:
            mirrored { side in
                var p = Path()
                p.move(to: g.point(c.x + side * r * 0.70, c.y - r * 0.45))
                p.addQuadCurve(to: g.point(c.x + side * r * 1.05, c.y + r * 0.65),
                               control: g.point(c.x + side * r * 1.55, c.y + r * 0.05))
                p.addQuadCurve(to: g.point(c.x + side * r * 0.55, c.y + r * 0.05),
                               control: g.point(c.x + side * r * 0.85, c.y + r * 0.45))
                p.closeSubpath()
                return p
            }
        case .horns:
            for side in [CGFloat(-1), 1] {
                var p = Path()
                p.move(to: g.point(c.x + side * r * 0.62, c.y - r * 0.62))
                p.addLine(to: g.point(c.x + side * r * 1.25, c.y - r * 1.20))
                p.addLine(to: g.point(c.x + side * r * 0.92, c.y - r * 0.45))
                p.closeSubpath()
                context.fill(p, with: .color(palette.accentColor))
                context.stroke(p, with: .color(ink), lineWidth: width)
            }
        case .fin:
            var p = Path()
            p.move(to: g.point(a.body.midX - 0.09, a.body.minY + 0.03))
            p.addLine(to: g.point(a.body.midX + 0.02, a.body.minY - 0.16))
            p.addLine(to: g.point(a.body.midX + 0.10, a.body.minY + 0.03))
            p.closeSubpath()
            context.fill(p, with: fill)
            context.stroke(p, with: .color(ink), lineWidth: width)
        case .antennae:
            for side in [CGFloat(-1), 1] {
                var stalk = Path()
                stalk.move(to: g.point(c.x + side * r * 0.35, c.y - r * 0.85))
                stalk.addQuadCurve(to: g.point(c.x + side * r * 0.95, c.y - r * 1.60),
                                   control: g.point(c.x + side * r * 0.45, c.y - r * 1.40))
                context.stroke(stalk, with: .color(palette.shadeColor), lineWidth: g.scale(0.016))
                let knob = circle(g, c.x + side * r * 0.95, c.y - r * 1.60, r * 0.20)
                context.fill(knob, with: .color(palette.accentColor))
                context.stroke(knob, with: .color(ink), lineWidth: width)
            }
        case .leaf:
            for side in [CGFloat(-1), 1] {
                var p = Path()
                p.move(to: g.point(c.x + side * r * 0.25, c.y - r * 0.85))
                p.addQuadCurve(to: g.point(c.x + side * r * 1.30, c.y - r * 1.35),
                               control: g.point(c.x + side * r * 1.20, c.y - r * 0.55))
                p.addQuadCurve(to: g.point(c.x + side * r * 0.25, c.y - r * 0.85),
                               control: g.point(c.x + side * r * 0.55, c.y - r * 1.55))
                context.fill(p, with: .color(palette.accentColor))
                context.stroke(p, with: .color(ink), lineWidth: width)
            }
        }
    }

    fileprivate func drawEyes(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let f = a.faceCenter
        let scale = a.faceScale
        let dx = scale * 0.23
        let y = f.y - scale * 0.06
        let (ink, width) = outline(g)
        let white = GraphicsContext.Shading.color(.white)
        let pupil = GraphicsContext.Shading.color(Palette.ink)

        switch recipe.eyes {
        case .big, .googly:
            let drift: CGFloat = recipe.eyes == .googly ? 0.035 : 0
            for side in [CGFloat(-1), 1] {
                let sclera = circle(g, f.x + side * dx, y, scale * 0.155)
                context.fill(sclera, with: white)
                context.stroke(sclera, with: .color(ink), lineWidth: width)
                context.fill(circle(g, f.x + side * dx + side * drift, y + drift, scale * 0.072),
                             with: pupil)
            }
        case .beady:
            for side in [CGFloat(-1), 1] {
                context.fill(circle(g, f.x + side * dx, y, scale * 0.055), with: pupil)
            }
        case .sleepy:
            for side in [CGFloat(-1), 1] {
                let sclera = circle(g, f.x + side * dx, y, scale * 0.14)
                context.fill(sclera, with: white)
                context.stroke(sclera, with: .color(ink), lineWidth: width)
                context.fill(circle(g, f.x + side * dx, y + scale * 0.045, scale * 0.062), with: pupil)
                var lid = Path()
                lid.move(to: g.point(f.x + side * dx - scale * 0.15, y - scale * 0.02))
                lid.addQuadCurve(to: g.point(f.x + side * dx + scale * 0.15, y - scale * 0.02),
                                 control: g.point(f.x + side * dx, y - scale * 0.20))
                context.stroke(lid, with: .color(ink), lineWidth: g.scale(0.018))
            }
        case .shades:
            var bar = Path()
            let box = CGRect(x: g.point(f.x - dx - scale * 0.20, y - scale * 0.11).x,
                             y: g.point(f.x - dx - scale * 0.20, y - scale * 0.11).y,
                             width: g.scale(dx * 2 + scale * 0.40),
                             height: g.scale(scale * 0.22))
            bar.addRoundedRect(in: box, cornerSize: CGSize(width: g.scale(scale * 0.06),
                                                           height: g.scale(scale * 0.06)))
            context.fill(bar, with: .color(Palette.ink))
            var glint = Path()
            glint.move(to: g.point(f.x - dx * 0.6, y + scale * 0.05))
            glint.addLine(to: g.point(f.x - dx * 0.2, y - scale * 0.06))
            context.stroke(glint, with: .color(.white.opacity(0.75)), lineWidth: g.scale(0.012))
        case .single:
            let sclera = circle(g, f.x, y, scale * 0.24)
            context.fill(sclera, with: white)
            context.stroke(sclera, with: .color(ink), lineWidth: width)
            context.fill(circle(g, f.x, y, scale * 0.10), with: pupil)
        }
    }

    fileprivate func drawMouth(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let f = a.faceCenter
        let scale = a.faceScale
        let y = f.y + scale * 0.26
        let (ink, _) = outline(g)
        let stroke = g.scale(0.016)

        switch recipe.mouth {
        case .flat:
            var p = Path()
            p.move(to: g.point(f.x - scale * 0.13, y))
            p.addLine(to: g.point(f.x + scale * 0.13, y))
            context.stroke(p, with: .color(ink), lineWidth: stroke)
        case .smile, .grin:
            var p = Path()
            p.move(to: g.point(f.x - scale * 0.18, y - scale * 0.04))
            p.addQuadCurve(to: g.point(f.x + scale * 0.18, y - scale * 0.04),
                           control: g.point(f.x, y + scale * 0.16))
            context.stroke(p, with: .color(ink), lineWidth: stroke)
            if recipe.mouth == .grin {
                var teeth = Path()
                teeth.move(to: g.point(f.x - scale * 0.15, y + scale * 0.005))
                teeth.addLine(to: g.point(f.x + scale * 0.15, y + scale * 0.005))
                context.stroke(teeth, with: .color(ink), lineWidth: g.scale(0.010))
            }
        case .gasp:
            let o = circle(g, f.x, y + scale * 0.03, scale * 0.11)
            context.fill(o, with: .color(Palette.ink))
        case .fangs:
            var p = Path()
            p.move(to: g.point(f.x - scale * 0.22, y - scale * 0.03))
            p.addQuadCurve(to: g.point(f.x + scale * 0.22, y - scale * 0.03),
                           control: g.point(f.x, y + scale * 0.14))
            context.stroke(p, with: .color(ink), lineWidth: stroke)
            for offset in [CGFloat(-0.12), 0.02] {
                var tooth = Path()
                tooth.move(to: g.point(f.x + offset, y - scale * 0.01))
                tooth.addLine(to: g.point(f.x + offset + scale * 0.05, y - scale * 0.01))
                tooth.addLine(to: g.point(f.x + offset + scale * 0.025, y + scale * 0.09))
                tooth.closeSubpath()
                context.fill(tooth, with: .color(.white))
                context.stroke(tooth, with: .color(ink), lineWidth: g.scale(0.008))
            }
        case .beak:
            break   // the beak is drawn with the head
        }
    }

    fileprivate func drawLimbs(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let r = a.body
        let (ink, width) = outline(g)
        let fill = GraphicsContext.Shading.color(palette.shadeColor)

        func limb(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            var p = Path()
            let origin = g.point(x, y)
            p.addRoundedRect(in: CGRect(x: origin.x, y: origin.y,
                                        width: g.scale(w), height: g.scale(h)),
                             cornerSize: CGSize(width: g.scale(w / 2), height: g.scale(w / 2)))
            context.fill(p, with: fill)
            context.stroke(p, with: .color(ink), lineWidth: width)
        }

        switch recipe.limbs {
        case .none:
            break
        case .stubby:
            limb(r.midX - 0.17, r.maxY - 0.03, 0.10, 0.14)
            limb(r.midX + 0.07, r.maxY - 0.03, 0.10, 0.14)
        case .long:
            limb(r.midX - 0.17, r.maxY - 0.04, 0.075, 0.22)
            limb(r.midX + 0.09, r.maxY - 0.04, 0.075, 0.22)
            limb(r.minX - 0.05, r.minY + r.height * 0.20, 0.065, 0.20)
            limb(r.maxX - 0.02, r.minY + r.height * 0.20, 0.065, 0.20)
        case .hooves:
            for x in [r.minX + 0.06, r.minX + 0.22, r.maxX - 0.30, r.maxX - 0.14] {
                limb(x, r.maxY - 0.03, 0.075, 0.18)
                var hoof = Path()
                let origin = g.point(x, r.maxY + 0.09)
                hoof.addRoundedRect(in: CGRect(x: origin.x, y: origin.y,
                                               width: g.scale(0.075), height: g.scale(0.06)),
                                    cornerSize: CGSize(width: g.scale(0.02), height: g.scale(0.02)))
                context.fill(hoof, with: .color(Palette.ink.opacity(0.8)))
            }
        case .fins:
            for side in [CGFloat(-1), 1] {
                var p = Path()
                let anchorX = side < 0 ? r.minX + 0.03 : r.maxX - 0.03
                p.move(to: g.point(anchorX, r.midY - 0.02))
                p.addQuadCurve(to: g.point(anchorX + side * 0.19, r.midY + 0.13),
                               control: g.point(anchorX + side * 0.18, r.midY - 0.06))
                p.addQuadCurve(to: g.point(anchorX, r.midY + 0.09),
                               control: g.point(anchorX + side * 0.07, r.midY + 0.12))
                p.closeSubpath()
                context.fill(p, with: fill)
                context.stroke(p, with: .color(ink), lineWidth: width)
            }
        case .wings:
            for side in [CGFloat(-1), 1] {
                var p = Path()
                p.move(to: g.point(r.midX, r.midY - 0.02))
                p.addLine(to: g.point(r.midX + side * 0.46, r.midY - 0.26))
                p.addLine(to: g.point(r.midX + side * 0.40, r.midY + 0.06))
                p.closeSubpath()
                context.fill(p, with: .linearGradient(
                    Gradient(colors: [palette.shadeColor, palette.bodyColor]),
                    startPoint: g.point(r.midX, r.midY), endPoint: g.point(r.midX + side * 0.4, r.midY)))
                context.stroke(p, with: .color(ink), lineWidth: width)
            }
        case .tentacles:
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                let x = r.minX + r.width * (0.10 + 0.80 * t)
                var p = Path()
                p.move(to: g.point(x, r.maxY - 0.04))
                p.addQuadCurve(to: g.point(x + (i.isMultiple(of: 2) ? 0.05 : -0.05), r.maxY + 0.14),
                               control: g.point(x + (i.isMultiple(of: 2) ? -0.04 : 0.04), r.maxY + 0.06))
                context.stroke(p, with: .color(palette.shadeColor),
                               style: StrokeStyle(lineWidth: g.scale(0.045), lineCap: .round))
            }
        }
    }
}

// MARK: - Props
//
// The object half of each mash-up. Split into a layer behind the body and a layer
// in front, because a Saturn ring has to pass behind the cow while a bomb has to
// hang in front of the crocodile.

extension CreatureRenderer {

    fileprivate func drawBackProps(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let r = a.body
        let (ink, _) = outline(g)

        switch recipe.prop {
        case .planetRing:
            var ring = Path()
            let box = CGRect(x: g.point(r.midX - 0.46, r.midY - 0.11).x,
                             y: g.point(r.midX - 0.46, r.midY - 0.11).y,
                             width: g.scale(0.92), height: g.scale(0.22))
            ring.addEllipse(in: box)
            context.stroke(ring, with: .color(palette.accentColor), lineWidth: g.scale(0.05))
            context.stroke(ring, with: .color(ink.opacity(0.4)), lineWidth: g.scale(0.008))

        case .sparkles:
            for (sx, sy, size) in [(0.14, 0.20, 0.055), (0.86, 0.30, 0.042),
                                   (0.20, 0.78, 0.035), (0.82, 0.70, 0.050)] {
                var star = Path()
                let c = g.point(CGFloat(sx), CGFloat(sy))
                let k = g.scale(CGFloat(size))
                star.move(to: CGPoint(x: c.x, y: c.y - k))
                star.addQuadCurve(to: CGPoint(x: c.x + k, y: c.y), control: c)
                star.addQuadCurve(to: CGPoint(x: c.x, y: c.y + k), control: c)
                star.addQuadCurve(to: CGPoint(x: c.x - k, y: c.y), control: c)
                star.addQuadCurve(to: CGPoint(x: c.x, y: c.y - k), control: c)
                context.fill(star, with: .color(palette.accentColor))
            }

        case .propeller:
            var blades = Path()
            blades.move(to: g.point(r.maxX - 0.02, r.midY - 0.16))
            blades.addLine(to: g.point(r.maxX + 0.03, r.midY + 0.16))
            context.stroke(blades, with: .color(ink.opacity(0.7)), lineWidth: g.scale(0.03))

        default:
            break
        }
    }

    fileprivate func drawFrontProps(_ context: inout GraphicsContext, _ g: Geometry, _ a: Anatomy) {
        let r = a.body
        let (ink, width) = outline(g)
        let accent = GraphicsContext.Shading.color(palette.accentColor)

        func stroked(_ path: Path, _ shading: GraphicsContext.Shading) {
            context.fill(path, with: shading)
            context.stroke(path, with: .color(ink), lineWidth: width)
        }

        func roundedBox(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> Path {
            var p = Path()
            let origin = g.point(x, y)
            p.addRoundedRect(in: CGRect(x: origin.x, y: origin.y,
                                        width: g.scale(w), height: g.scale(h)),
                             cornerSize: CGSize(width: g.scale(radius), height: g.scale(radius)))
            return p
        }

        switch recipe.prop {
        case .none, .planetRing, .sparkles, .propeller:
            break

        case .sneakers:
            // Three of them. That is the whole joke.
            for x in [r.midX - 0.30, r.midX - 0.05, r.midX + 0.20] {
                stroked(roundedBox(x, r.maxY + 0.05, 0.16, 0.075, 0.032), .color(.white))
                var swoosh = Path()
                swoosh.move(to: g.point(x + 0.02, r.maxY + 0.10))
                swoosh.addQuadCurve(to: g.point(x + 0.13, r.maxY + 0.068),
                                    control: g.point(x + 0.08, r.maxY + 0.11))
                context.stroke(swoosh, with: accent, lineWidth: g.scale(0.014))
            }

        case .bomb:
            let bomb = circle(g, r.midX + 0.02, r.maxY + 0.06, 0.115)
            stroked(bomb, .color(Palette.ink))
            var fuse = Path()
            fuse.move(to: g.point(r.midX + 0.08, r.maxY - 0.03))
            fuse.addQuadCurve(to: g.point(r.midX + 0.17, r.maxY - 0.12),
                              control: g.point(r.midX + 0.17, r.maxY - 0.02))
            context.stroke(fuse, with: .color(palette.accentColor), lineWidth: g.scale(0.018))
            context.fill(circle(g, r.midX + 0.17, r.maxY - 0.135, 0.028), with: .color(Color(hex: 0xFFB030)))

        case .coffeeCup:
            stroked(roundedBox(r.maxX - 0.02, r.midY - 0.04, 0.17, 0.20, 0.03), .color(.white))
            var handle = Path()
            handle.addArc(center: g.point(r.maxX + 0.16, r.midY + 0.06), radius: g.scale(0.06),
                          startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
            context.stroke(handle, with: .color(ink), lineWidth: g.scale(0.016))

        case .cactus:
            for side in [CGFloat(-1), 1] {
                stroked(roundedBox(r.midX + side * 0.22 - (side < 0 ? 0.08 : 0), r.minY + 0.16,
                                   0.09, 0.24, 0.045), .color(palette.bodyColor))
            }

        case .banana:
            var peel = Path()
            peel.move(to: g.point(r.midX - 0.24, r.minY + 0.10))
            peel.addQuadCurve(to: g.point(r.midX + 0.24, r.minY + 0.10),
                              control: g.point(r.midX, r.maxY + 0.10))
            peel.addQuadCurve(to: g.point(r.midX - 0.24, r.minY + 0.10),
                              control: g.point(r.midX, r.maxY - 0.06))
            stroked(peel, .color(Color(hex: 0xF2C63D)))

        case .drumstick:
            var bat = Path()
            bat.move(to: g.point(r.maxX + 0.02, r.maxY - 0.02))
            bat.addLine(to: g.point(r.maxX + 0.20, r.minY + 0.06))
            context.stroke(bat, with: .color(palette.accentColor),
                           style: StrokeStyle(lineWidth: g.scale(0.055), lineCap: .round))
            context.stroke(bat, with: .color(ink), style: StrokeStyle(lineWidth: g.scale(0.008)))

        case .melon:
            var wedge = Path()
            wedge.move(to: g.point(r.midX - 0.20, r.midY + 0.16))
            wedge.addLine(to: g.point(r.midX + 0.20, r.midY + 0.16))
            wedge.addArc(center: g.point(r.midX, r.midY + 0.16), radius: g.scale(0.20),
                         startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            stroked(wedge, .color(palette.accentColor))
            for dx in [CGFloat(-0.09), 0, 0.09] {
                context.fill(circle(g, r.midX + dx, r.midY + 0.24, 0.016), with: .color(Palette.ink))
            }

        case .pineapple:
            for side in [CGFloat(-1), 0, 1] {
                var frond = Path()
                frond.move(to: g.point(r.midX + side * 0.05, r.minY + 0.02))
                frond.addLine(to: g.point(r.midX + side * 0.16, r.minY - 0.18))
                frond.addLine(to: g.point(r.midX + side * 0.11, r.minY + 0.02))
                frond.closeSubpath()
                stroked(frond, accent)
            }

        case .tyre:
            var tyre = Path()
            let outer = CGRect(x: g.point(r.midX - 0.30, r.midY - 0.24).x,
                               y: g.point(r.midX - 0.30, r.midY - 0.24).y,
                               width: g.scale(0.60), height: g.scale(0.48))
            tyre.addEllipse(in: outer)
            context.stroke(tyre, with: .color(Color(hex: 0x2A2A2E)), lineWidth: g.scale(0.085))
            context.stroke(tyre, with: .color(ink.opacity(0.5)), lineWidth: g.scale(0.008))

        case .coconut:
            for (dx, dy) in [(CGFloat(-0.09), CGFloat(-0.03)), (0.09, -0.03), (0, 0.09)] {
                context.fill(circle(g, r.midX + dx, r.midY + dy, 0.038),
                             with: .color(Palette.ink.opacity(0.75)))
            }

        case .berry:
            for side in [CGFloat(-1), 0, 1] {
                var leaf = Path()
                leaf.move(to: g.point(r.midX, r.minY - 0.01))
                leaf.addQuadCurve(to: g.point(r.midX + side * 0.16, r.minY - 0.11),
                                  control: g.point(r.midX + side * 0.15, r.minY - 0.02))
                leaf.addQuadCurve(to: g.point(r.midX, r.minY - 0.01),
                                  control: g.point(r.midX + side * 0.05, r.minY - 0.09))
                stroked(leaf, accent)
            }

        case .ball:
            for (dx, dy) in [(CGFloat(0), CGFloat(-0.10)), (-0.15, 0.08), (0.15, 0.08)] {
                var patch = Path()
                let c = g.point(r.midX + dx, r.midY + dy)
                let k = g.scale(0.075)
                for i in 0..<5 {
                    let angle = Double(i) / 5 * 2 * .pi - .pi / 2
                    let point = CGPoint(x: c.x + cos(angle) * k, y: c.y + sin(angle) * k)
                    if i == 0 { patch.move(to: point) } else { patch.addLine(to: point) }
                }
                patch.closeSubpath()
                stroked(patch, .color(Palette.ink))
            }

        case .clock:
            let face = circle(g, r.maxX + 0.06, r.midY - 0.02, 0.115)
            stroked(face, .color(.white))
            var hands = Path()
            hands.move(to: g.point(r.maxX + 0.06, r.midY - 0.02))
            hands.addLine(to: g.point(r.maxX + 0.06, r.midY - 0.10))
            hands.move(to: g.point(r.maxX + 0.06, r.midY - 0.02))
            hands.addLine(to: g.point(r.maxX + 0.12, r.midY - 0.02))
            context.stroke(hands, with: .color(Palette.ink), lineWidth: g.scale(0.014))

        case .cigar:
            stroked(roundedBox(a.faceCenter.x + 0.05, a.faceCenter.y + a.faceScale * 0.22,
                               0.20, 0.045, 0.02), .color(Color(hex: 0x6B4A2A)))
            context.fill(circle(g, a.faceCenter.x + 0.26, a.faceCenter.y + a.faceScale * 0.24, 0.022),
                         with: .color(Color(hex: 0xFF7A30)))

        case .fridge:
            stroked(roundedBox(r.minX - 0.12, r.minY - 0.04, 0.20, 0.34, 0.03), accent)
            var handle = Path()
            handle.move(to: g.point(r.minX - 0.005, r.minY + 0.06))
            handle.addLine(to: g.point(r.minX - 0.005, r.minY + 0.16))
            context.stroke(handle, with: .color(ink), lineWidth: g.scale(0.016))

        case .blade:
            for side in [CGFloat(-1), 1] {
                var sword = Path()
                sword.move(to: g.point(r.midX + side * 0.10, r.maxY - 0.02))
                sword.addLine(to: g.point(r.midX + side * 0.40, r.minY - 0.06))
                context.stroke(sword, with: .color(Color(hex: 0xD8DCE4)),
                               style: StrokeStyle(lineWidth: g.scale(0.030), lineCap: .round))
                context.stroke(sword, with: .color(ink), style: StrokeStyle(lineWidth: g.scale(0.007)))
            }

        case .tutu:
            var skirt = Path()
            skirt.move(to: g.point(r.midX - 0.12, r.maxY - 0.10))
            skirt.addQuadCurve(to: g.point(r.midX + 0.12, r.maxY - 0.10),
                               control: g.point(r.midX, r.maxY - 0.02))
            skirt.addLine(to: g.point(r.midX + 0.30, r.maxY + 0.04))
            skirt.addQuadCurve(to: g.point(r.midX - 0.30, r.maxY + 0.04),
                               control: g.point(r.midX, r.maxY + 0.14))
            skirt.closeSubpath()
            stroked(skirt, accent)
        }
    }
}
