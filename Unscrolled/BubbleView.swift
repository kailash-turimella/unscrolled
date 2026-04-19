import SwiftUI

struct BubbleCircleView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.75))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )

            Image(systemName: "eye.slash.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    BubbleCircleView()
        .padding()
        .background(Color.gray)
}
