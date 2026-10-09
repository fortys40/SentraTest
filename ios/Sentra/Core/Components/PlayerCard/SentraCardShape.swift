import SwiftUI

struct SentraCardShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let vertices: [CGPoint] = [
            CGPoint(x: 0.04, y: 0.065), CGPoint(x: 0.19, y: 0.025),
            CGPoint(x: 0.41, y: 0.025), CGPoint(x: 0.50, y: 0.049),
            CGPoint(x: 0.59, y: 0.025), CGPoint(x: 0.81, y: 0.025),
            CGPoint(x: 0.96, y: 0.065), CGPoint(x: 0.94, y: 0.855),
            CGPoint(x: 0.83, y: 0.920), CGPoint(x: 0.50, y: 0.987),
            CGPoint(x: 0.17, y: 0.920), CGPoint(x: 0.06, y: 0.855)
        ]
        return Path { path in
            for (index, vertex) in vertices.enumerated() {
                let point = CGPoint(x: bounds.minX + vertex.x * bounds.width,
                                    y: bounds.minY + vertex.y * bounds.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }

    func inset(by amount: CGFloat) -> SentraCardShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct SentraPortraitFrame: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        func point(_ horizontal: CGFloat, _ vertical: CGFloat) -> CGPoint {
            CGPoint(x: bounds.minX + horizontal * bounds.width, y: bounds.minY + vertical * bounds.height)
        }
        return Path { path in
            path.move(to: point(0.06, 0.08))
            path.addLine(to: point(0.21, 0.025))
            path.addQuadCurve(to: point(0.79, 0.025), control: point(0.5, 0.0))
            path.addLine(to: point(0.94, 0.08))
            path.addLine(to: point(0.89, 0.73))
            path.addQuadCurve(to: point(0.50, 0.985), control: point(0.84, 0.865))
            path.addQuadCurve(to: point(0.11, 0.73), control: point(0.16, 0.865))
            path.closeSubpath()
        }
    }

    func inset(by amount: CGFloat) -> SentraPortraitFrame {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct CardMaterial: View {
    let style: CardTierStyle

    var body: some View {
        style.material.overlay {
            Canvas { context, size in
                for index in 0..<56 {
                    let offset = CGFloat(index) / 55
                    var grain = Path()
                    if style.hasMarbleTexture {
                        grain.move(to: CGPoint(x: -size.width * 0.2, y: offset * size.height))
                        grain.addCurve(to: CGPoint(x: size.width * 1.2, y: (offset + 0.1) * size.height),
                                       control1: CGPoint(x: size.width * 0.33, y: (offset - 0.07) * size.height),
                                       control2: CGPoint(x: size.width * 0.68, y: (offset + 0.16) * size.height))
                    } else {
                        grain.move(to: CGPoint(x: 0, y: offset * size.height))
                        grain.addLine(to: CGPoint(x: size.width, y: (offset + 0.035) * size.height))
                    }
                    context.stroke(grain, with: .color(style.accent.opacity(index.isMultiple(of: 5) ? 0.10 : 0.035)),
                                   lineWidth: index.isMultiple(of: 5) ? 0.65 : 0.35)
                }
                for index in 0..<7 {
                    let level = CGFloat(index) * size.height * 0.15
                    var chevron = Path()
                    chevron.move(to: CGPoint(x: 0, y: level))
                    chevron.addLine(to: CGPoint(x: size.width / 2, y: level + size.height * 0.13))
                    chevron.addLine(to: CGPoint(x: size.width, y: level))
                    context.stroke(chevron, with: .color(style.accent.opacity(0.09)), lineWidth: 0.7)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct SentraCardCrest: View {
    let style: CardTierStyle

    var body: some View {
        HStack(spacing: -3) {
            Image(systemName: "laurel.leading")
            Image(systemName: "soccerball").font(.system(size: 22, weight: .semibold))
            Image(systemName: "laurel.trailing")
        }
        .font(.system(size: 28))
        .foregroundStyle(style.ink)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(style.material, in: SentraPortraitFrame())
        .overlay { SentraPortraitFrame().strokeBorder(style.metal, lineWidth: 1) }
        .accessibilityHidden(true)
    }
}