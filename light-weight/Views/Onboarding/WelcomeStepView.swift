import SwiftUI

struct WelcomeStepView: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: 0x0A0A0A))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: 12) {
                    Text("Your AI-powered\ntraining partner")
                        .font(.custom("SpaceGrotesk-Bold", size: 28))
                        .tracking(-0.84)
                        .foregroundStyle(Color(hex: 0x0A0A0A))
                        .multilineTextAlignment(.center)

                    Text("Personalized workouts that adapt to your recovery, sleep, and progress. Let's set things up.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.black.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("Get Started")
                        .font(.custom("SpaceGrotesk-Bold", size: 17))
                        .tracking(-0.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: 0x0A0A0A))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Takes about 2 minutes")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
