import SwiftUI

struct HotkeyBadge: View {
    let combo: HotkeyCombo

    var body: some View {
        Text(combo.displayString)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}
