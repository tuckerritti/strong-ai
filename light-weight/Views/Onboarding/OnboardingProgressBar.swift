import SwiftUI

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < current ? Color(hex: 0x0A0A0A) : Color.black.opacity(0.08))
                    .frame(width: 45, height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
