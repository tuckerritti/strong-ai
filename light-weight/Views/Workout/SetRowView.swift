import SwiftUI

private func debugSetRowLog(_ message: String) {
    DebugLogStore.record(message, category: "SetRow")
}

struct SetRowView: View {
    private static let errorPulseCount = 3

    let setNumber: Int
    let logSet: LogSet
    let plannedSet: WorkoutSet?
    let isActive: Bool
    let isAdjusting: Bool
    let adjustmentFailed: Bool
    let onLog: (Double, Int, Int) -> Void
    var onEdit: ((Double, Int, Int) -> Void)? = nil

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpeText: String = ""
    @State private var didInit = false
    @State private var sweepProgress: CGFloat = 1.3
    @State private var pulseOpacity: Double = 0.0
    @State private var isEditing = false

    private var isCompleted: Bool { logSet.completedAt != nil }
    private var canLog: Bool {
        guard let rpe = Int(rpeText) else { return false }
        return Double(weightText) != nil && Int(repsText) != nil && (1...10).contains(rpe)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isCompleted ? Color.accent : .textSecondary)
                .frame(width: 40, alignment: .leading)

            if isCompleted && isEditing {
                editingRow
            } else if isCompleted {
                completedRow
            } else if isActive {
                activeRow
            } else {
                futureRow
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(
            isActive
                ? RoundedRectangle(cornerRadius: 10).stroke(Color.textPrimary, lineWidth: 1.5).padding(.horizontal, 8)
                : nil
        )
        .onAppear {
            guard !didInit else { return }
            didInit = true
            syncDisplayedValues()
            debugSetRowLog("Row \(self.setNumber) appeared active=\(self.isActive) completed=\(self.isCompleted) adjusting=\(self.isAdjusting)")
            if isAdjusting {
                startSweep()
            }
        }
        .onChange(of: logSet.weight) {
            syncPendingValues()
        }
        .onChange(of: logSet.reps) {
            syncPendingValues()
        }
        .onChange(of: logSet.rpe) {
            if isCompleted {
                rpeText = logSet.rpe > 0 ? String(logSet.rpe) : ""
            }
        }
        .opacity(isAdjusting && !isCompleted ? 0.5 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isAdjusting)
        .overlay {
            if !isCompleted {
                GeometryReader { proxy in
                    let bandWidth: CGFloat = 72
                    let travel = proxy.size.width + (bandWidth * 2)
                    let xOffset = (travel * sweepProgress) - bandWidth

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.0),
                                    Color.gray.opacity(0.45),
                                    Color.gray.opacity(0.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: bandWidth)
                        .opacity(isAdjusting ? 0.9 : 0)
                        .offset(x: xOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .clipped()
                        .allowsHitTesting(false)
                }
            }
        }
        .background {
            Rectangle()
                .fill(Color.red)
                .opacity(pulseOpacity)
        }
        .onChange(of: adjustmentFailed) {
            guard !isCompleted else { return }

            guard adjustmentFailed else {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    pulseOpacity = 0.0
                }
                return
            }

            pulseOpacity = 0.0
            withAnimation(
                .easeInOut(duration: 0.25)
                    .repeatCount(Self.errorPulseCount * 2, autoreverses: true)
            ) {
                pulseOpacity = 0.3
            }
        }
        .onChange(of: isAdjusting) {
            debugSetRowLog("Row \(self.setNumber) adjusting=\(self.isAdjusting) completed=\(self.isCompleted)")
            if isAdjusting {
                startSweep()
            } else {
                stopSweep()
            }
        }
        .onDisappear {
            stopSweep()
        }
    }

    // MARK: - Completed

    @ViewBuilder
    private var completedRow: some View {
        Text(weightText)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
        Text(repsText)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
        Text(rpeText.isEmpty ? "—" : rpeText)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 48, alignment: .center)
        Button {
            isEditing = true
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accent)
                .frame(width: 28)
        }
        .accessibilityLabel("Edit set")
    }

    // MARK: - Editing

    @ViewBuilder
    private var editingRow: some View {
        NumericTextField(text: $weightText, placeholder: "0", keyboardType: .decimalPad)
            .frame(maxWidth: .infinity)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        NumericTextField(text: $repsText, placeholder: "0", keyboardType: .numberPad)
            .frame(maxWidth: .infinity)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        NumericTextField(text: $rpeText, placeholder: "—", keyboardType: .numberPad)
            .frame(width: 48)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        Button {
            guard let weight = Double(weightText),
                  let reps = Int(repsText),
                  let rpe = Int(rpeText) else { return }
            onEdit?(weight, reps, rpe)
            isEditing = false
        } label: {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(canLog ? Color.accent : .textQuaternary)
        }
        .disabled(!canLog)
        .frame(width: 28)
        .accessibilityLabel("Save edit")
    }

    // MARK: - Active

    @ViewBuilder
    private var activeRow: some View {
        NumericTextField(text: $weightText, placeholder: "0", keyboardType: .decimalPad)
            .frame(maxWidth: .infinity)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        NumericTextField(text: $repsText, placeholder: "0", keyboardType: .numberPad)
            .frame(maxWidth: .infinity)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        NumericTextField(text: $rpeText, placeholder: plannedSet?.targetRpe.map { "@\($0)" } ?? "—", keyboardType: .numberPad)
            .frame(width: 48)
            .frame(height: 33)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        Button {
            guard let weight = Double(weightText),
                  let reps = Int(repsText),
                  let rpe = Int(rpeText) else { return }
            onLog(weight, reps, rpe)
        } label: {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(canLog ? Color.textPrimary : .textQuaternary)
        }
        .disabled(!canLog)
        .frame(width: 28)
        .accessibilityLabel(canLog ? "Log set" : "Enter weight, reps, and RPE (1–10) to log")
    }

    // MARK: - Future

    @ViewBuilder
    private var futureRow: some View {
        Text(plannedSet.map { "\(Int($0.weight))" } ?? "—")
            .font(.system(size: 14))
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity)
        Text(plannedSet.map { "\($0.reps)" } ?? "—")
            .font(.system(size: 14))
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity)
        Text(plannedSet?.targetRpe.map { "@\($0)" } ?? "—")
            .font(.system(size: 14))
            .foregroundStyle(Color.textTertiary)
            .frame(width: 48, alignment: .center)
        Circle()
            .strokeBorder(Color.divider, lineWidth: 1.5)
            .frame(width: 20, height: 20)
            .frame(width: 28)
    }

    private func syncDisplayedValues() {
        weightText = logSet.weight > 0 ? "\(Int(logSet.weight))" : ""
        repsText = "\(logSet.reps)"
        rpeText = logSet.rpe > 0 ? String(logSet.rpe) : ""
    }

    private func syncPendingValues() {
        guard !isCompleted else { return }
        weightText = logSet.weight > 0 ? "\(Int(logSet.weight))" : ""
        repsText = "\(logSet.reps)"
    }

    private func startSweep() {
        guard !isCompleted else { return }

        debugSetRowLog("Starting sweep row=\(self.setNumber) active=\(self.isActive)")

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sweepProgress = -0.3
        }

        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            sweepProgress = 1.3
        }
    }

    private func stopSweep() {
        debugSetRowLog("Stopping sweep row=\(self.setNumber) completed=\(self.isCompleted)")

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sweepProgress = 1.3
        }
    }
}
