import SwiftUI

struct HoverableAccentButtonLabel: View {
    let text: String
    var fontSize: CGFloat = 20
    var cornerRadius: CGFloat = 14

    @State private var hovered = false

    var body: some View {
        Text(text)
            .font(.custom("BebasNeue-Regular", size: fontSize))
            .tracking(3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.cbAccent)
            .overlay(hovered ? Color.black.opacity(0.12) : Color.clear)
            .cornerRadius(cornerRadius)
            .onHover { isHovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hovered = isHovering
                }
            }
    }
}
