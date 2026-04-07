import SwiftUI

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < current ? Color.buttonPrimary : Color.divider)
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
