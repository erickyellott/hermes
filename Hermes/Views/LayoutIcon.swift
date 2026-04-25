import SwiftUI

struct LayoutIcon: View {
    let kind: LayoutKind
    var size: CGSize = CGSize(width: 44, height: 30)

    var body: some View {
        Canvas { ctx, sz in
            let r = CGRect(origin: .zero, size: sz)
            draw(ctx: ctx, rect: r)
        }
        .frame(width: size.width, height: size.height)
    }

    private func draw(ctx: GraphicsContext, rect: CGRect) {
        let corner: CGFloat = 3
        let gap: CGFloat = 2

        switch kind {
        case .leftTwoThirds:
            let leftW = rect.width * 2 / 3 - gap / 2
            let rightW = rect.width / 3 - gap / 2
            fill(ctx, CGRect(x: 0, y: 0, width: leftW, height: rect.height), corner, bright: true)
            fill(ctx, CGRect(x: leftW + gap, y: 0, width: rightW, height: rect.height), corner, bright: false)

        case .rightOneThird:
            let leftW = rect.width * 2 / 3 - gap / 2
            let rightW = rect.width / 3 - gap / 2
            fill(ctx, CGRect(x: 0, y: 0, width: leftW, height: rect.height), corner, bright: false)
            fill(ctx, CGRect(x: leftW + gap, y: 0, width: rightW, height: rect.height), corner, bright: true)

        case .leftHalf:
            let halfW = (rect.width - gap) / 2
            fill(ctx, CGRect(x: 0, y: 0, width: halfW, height: rect.height), corner, bright: true)
            fill(ctx, CGRect(x: halfW + gap, y: 0, width: halfW, height: rect.height), corner, bright: false)

        case .rightHalf:
            let halfW = (rect.width - gap) / 2
            fill(ctx, CGRect(x: 0, y: 0, width: halfW, height: rect.height), corner, bright: false)
            fill(ctx, CGRect(x: halfW + gap, y: 0, width: halfW, height: rect.height), corner, bright: true)

        case .maximize:
            fill(ctx, CGRect(origin: .zero, size: rect.size), corner, bright: true)
        }
    }

    private func fill(
        _ ctx: GraphicsContext,
        _ rect: CGRect,
        _ corner: CGFloat,
        bright: Bool
    ) {
        let path = Path(roundedRect: rect, cornerRadius: corner)
        ctx.fill(path, with: .color(.white.opacity(bright ? 0.85 : 0.2)))
    }
}
