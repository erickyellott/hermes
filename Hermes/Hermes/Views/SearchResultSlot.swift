import SwiftUI
import UniformTypeIdentifiers

struct SearchResultSlot: View {
    let result: SearchResult

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: result.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 54)
                .frame(width: 72, height: 72)
                .background(.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .draggable(result.url)

            Text(result.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(width: 90, height: 110)
    }
}
