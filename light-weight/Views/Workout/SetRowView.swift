import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    let logSet: LogSet
    let plannedSet: WorkoutSet?
    let isActive: Bool
    let onLog: (Double, Int, Int?) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpeText: String = ""
    @State private var didInit = false

    private var isCompleted: Bool { logSet.completedAt != nil }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isCompleted ? Color(hex: 0x34C759) : Color.black.opacity(0.4))
                .frame(width: 40, alignment: .leading)

            if isCompleted {
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
                ? RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x0A0A0A), lineWidth: 1.5).padding(.horizontal, 8)
                : nil
        )
        .onAppear {
            guard !didInit else { return }
            didInit = true
            if let ps = plannedSet {
                weightText = ps.weight > 0 ? "\(Int(ps.weight))" : ""
                repsText = "\(ps.reps)"
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
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color(hex: 0x34C759))
            .frame(width: 28)
    }

    // MARK: - Active

    @ViewBuilder
    private var activeRow: some View {
        TextField("0", text: $weightText)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(hex: 0xF5F5F5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        TextField("0", text: $repsText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(hex: 0xF5F5F5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        TextField("—", text: $rpeText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(Color(hex: 0xF5F5F5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        Button {
            let weight = Double(weightText) ?? 0
            let reps = Int(repsText) ?? 0
            let rpe = Int(rpeText)
            onLog(weight, reps, rpe)
        } label: {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(Color.black.opacity(0.3))
        }
        .frame(width: 28)
    }

    // MARK: - Future

    @ViewBuilder
    private var futureRow: some View {
        Text(plannedSet.map { "\(Int($0.weight))" } ?? "—")
            .font(.system(size: 14))
            .foregroundStyle(Color.black.opacity(0.2))
            .frame(maxWidth: .infinity)
        Text(plannedSet.map { "\($0.reps)" } ?? "—")
            .font(.system(size: 14))
            .foregroundStyle(Color.black.opacity(0.2))
            .frame(maxWidth: .infinity)
        Text("—")
            .font(.system(size: 14))
            .foregroundStyle(Color.black.opacity(0.2))
            .frame(width: 48, alignment: .center)
        Circle()
            .strokeBorder(Color.black.opacity(0.1), lineWidth: 1.5)
            .frame(width: 20, height: 20)
            .frame(width: 28)
    }
}
