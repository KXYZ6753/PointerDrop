import AppKit

enum Badge { case none, clock, check }

/// Menu bar glyph: the app's dart and rain, plus an optional badge at the bottom right.
/// With no color it is a template image (the system tints it); with a color the whole icon is that color.
func menuIcon(_ badge: Badge, color: NSColor? = nil) -> NSImage {
    let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { r in
        let c = NSGraphicsContext.current!.cgContext
        c.scaleBy(x: r.width / 24, y: r.height / 24)  // 24-unit design grid, y down
        let ink = (color ?? .black).cgColor
        c.setFillColor(ink); c.setStrokeColor(ink)
        c.setLineCap(.round); c.setLineJoin(.round)

        c.setLineWidth(1.6)
        for (x, y1, y2, a) in [(12, 1.5, 5.5, 1.0), (8, 3, 6, 0.55), (16, 3, 6, 0.55)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            c.setAlpha(a)
            c.move(to: CGPoint(x: x, y: y1)); c.addLine(to: CGPoint(x: x, y: y2)); c.strokePath()
        }
        c.setAlpha(1)

        c.setLineWidth(1.2)
        c.move(to: CGPoint(x: 12, y: 21)); c.addLine(to: CGPoint(x: 7, y: 10))
        c.addLine(to: CGPoint(x: 12, y: 12.5)); c.addLine(to: CGPoint(x: 17, y: 10)); c.closePath()
        c.drawPath(using: .fillStroke)

        guard badge != .none else { return true }
        let o = CGPoint(x: 19, y: 19)
        func circle(_ rad: CGFloat) { c.fillEllipse(in: CGRect(x: o.x - rad, y: o.y - rad, width: rad * 2, height: rad * 2)) }
        c.setBlendMode(.clear); circle(6.6)             // gap around the badge
        c.setBlendMode(.normal); circle(5)
        c.setBlendMode(.clear); c.setLineWidth(1.4)     // symbol cut out of the badge
        if badge == .clock {
            c.move(to: CGPoint(x: 19, y: 16)); c.addLine(to: CGPoint(x: 19, y: 19)); c.addLine(to: CGPoint(x: 21, y: 20.2))
        } else {
            c.move(to: CGPoint(x: 16.7, y: 19.2)); c.addLine(to: CGPoint(x: 18.4, y: 20.9)); c.addLine(to: CGPoint(x: 21.5, y: 17.3))
        }
        c.strokePath()
        c.setBlendMode(.normal)
        return true
    }
    img.isTemplate = color == nil
    return img
}
