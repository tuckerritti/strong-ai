import SwiftUI

struct SoundsStepView: View {
    @Binding var selectedSounds: Set<RestSound>
    var onNext: () -> Void

    @State private var soundPreview = RestSoundService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(current: 7, total: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Set completion sounds")
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
                    .tracking(-0.84)
                    .foregroundStyle(Color.textPrimary)

                Text("Pick the sounds that play when your rest timer ends.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(RestSound.allCases) { sound in
                    let selected = selectedSounds.contains(sound)
                    Button {
                        if selected {
                            if selectedSounds.count > 1 {
                                selectedSounds.remove(sound)
                            }
                        } else {
                            selectedSounds.insert(sound)
                            soundPreview.previewSound(sound)
                        }
                        RestSound.selected = selectedSounds
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(selected ? Color.accent : Color.divider, lineWidth: selected ? 0 : 1.5)
                                    .frame(width: 24, height: 24)
                                if selected {
                                    Circle()
                                        .fill(Color.accent)
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                }
                            }
                            Text(sound.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selected ? Color.buttonPrimaryText : Color.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background(selected ? Color.buttonPrimary : Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .font(.custom("SpaceGrotesk-Bold", size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(Color.buttonPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .sensoryFeedback(.selection, trigger: selectedSounds)
    }
}
