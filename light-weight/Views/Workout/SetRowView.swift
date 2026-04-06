import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let logSet: LogSet
    let plannedSet: WorkoutSet?
    let isActive: Bool
    let isUpdating: Bool
    let isAdjusting: Bool
    let adjustmentFailed: Bool
    let onLog: (Double, Int, Int) -> Void
    var onEdit: ((Double, Int, Int) -> Void)? = nil

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpeText: String = ""
    @State private var didInit = false
    @State private var sweepPosition: CGFloat = 1.3
    @State private var contentOpacity: Double = 1.0
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
        .opacity((isAdjusting && !isCompleted ? 0.5 : 1.0) * contentOpacity)
        .animation(.easeOut(duration: 0.2), value: isAdjusting)
        .overlay {
            if !isCompleted {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, min(1, sweepPosition - 0.15))),
                                .init(color: Color.textQuaternary, location: max(0, min(1, sweepPosition))),
                                .init(color: .clear, location: max(0, min(1, sweepPosition + 0.15))),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(sweepPosition < 1.3 ? 1 : 0)
                .allowsHitTesting(false)
            }
        }
        .background {
            Rectangle()
                .fill(adjustmentFailed ? Color.red : Color.gray)
                .opacity(pulseOpacity)
        }
        .onChange(of: adjustmentFailed) {
            guard adjustmentFailed, !isCompleted else { return }
            pulseOpacity = 0.0
            withAnimation(.easeInOut(duration: 0.25).repeatCount(10, autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
        .onChange(of: isUpdating) {
            guard isUpdating, !isCompleted else { return }
            sweepPosition = -0.3
            contentOpacity = 0.3
            withAnimation(.easeOut(duration: 0.8)) {
                sweepPosition = 1.3
                contentOpacity = 1.0
            }
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
}
