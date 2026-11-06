import SwiftUI

struct DialogueBubble: Shape {
    var trailing: Bool
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 24, y: 1))
        path.addCurve(to: CGPoint(x: w-16, y: 1), control1: CGPoint(x: w*0.35, y: 0), control2: CGPoint(x: w*0.7, y: 2))
        path.addQuadCurve(to: CGPoint(x: w-1, y: 15), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w-2, y: h-23))
        path.addQuadCurve(to: CGPoint(x: w-16, y: h-8), control: CGPoint(x: w, y: h-7))
        path.addLine(to: CGPoint(x: 30, y: h-8))
        path.addQuadCurve(to: CGPoint(x: 4, y: h-2), control: CGPoint(x: 16, y: h-1))
        path.addQuadCurve(to: CGPoint(x: 11, y: h-22), control: CGPoint(x: 12, y: h-10))
        path.addLine(to: CGPoint(x: 10, y: 15))
        path.addQuadCurve(to: CGPoint(x: 24, y: 1), control: CGPoint(x: 9, y: 0))
        path.closeSubpath()
        return trailing ? path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)) : path
    }
}
