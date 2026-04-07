import Charts
import MuscleMap
import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Query(
        filter: #Predicate<WorkoutLog> { $0.finishedAt != nil },
        sort: \WorkoutLog.startedAt,
        order: .reverse
    ) var allLogs: [WorkoutLog]
    @Query var profiles: [UserProfile]

    var bodyGender: BodyGender {
        guard let gender = profiles.first?.gender else { return .male }
        return gender.localizedCaseInsensitiveCompare("Female") == .orderedSame ? .female : .male
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleArea
                exerciseImage
                descriptionSection
                targetMusclesSection
                howToSection
                statsSection
                progressChartSection
                recentHistorySection
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Title Area

    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.custom("SpaceGrotesk-Bold", size: 28))
                .tracking(-0.56)
                .foregroundStyle(Color.textHeading)
            Text(exercise.muscleGroup.uppercased())
                .font(.system(size: 13, weight: .medium))
                .tracking(0.52)
                .foregroundStyle(Color.accentAlt)
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Exercise Image

    private var exerciseImage: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.appSurfaceSubtle)
            .frame(height: 200)
            .overlay {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.textMuted.opacity(0.5))
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = exercise.exerciseDescription, !description.isEmpty {
            Text(description)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(7)
                .foregroundStyle(Color.textBody)
                .padding(.top, 20)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Target Muscles

    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Muscles")
                .font(.custom("SpaceGrotesk-Bold", size: 18))
                .tracking(-0.18)
                .foregroundStyle(Color.textHeading)

            if targetMuscleRows.isEmpty {
                Text("Target muscles aren't available for this exercise yet.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        targetMuscleMapView(side: .front, title: "FRONT")
                        targetMuscleMapView(side: .back, title: "BACK")
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(targetMuscleRows.enumerated()), id: \.element.id) { index, row in
                            HStack {
                                Text(row.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textHeading)

                                Spacer()

                                Text("\(row.percentage)%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.vertical, 10)

                            if index < targetMuscleRows.count - 1 {
                                Divider()
                                    .background(Color.appSurfaceAlt)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.appSurfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
    }

    private func targetMuscleMapView(side: BodySide, title: String) -> some View {
        VStack(spacing: 8) {
            BodyView(gender: bodyGender, side: side, style: .minimal)
                .showSubGroups()
                .heatmap(targetMuscleMapIntensities, colorScale: targetMuscleColorScale)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .allowsHitTesting(false)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - How to Perform

    @ViewBuilder
    private var howToSection: some View {
        let steps = exercise.instructions
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Perform")
                    .font(.custom("SpaceGrotesk-Bold", size: 18))
                    .tracking(-0.18)
                    .foregroundStyle(Color.textHeading)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.buttonPrimaryText)
                            .frame(width: 24, height: 24)
                            .background(Color.textHeading)
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(6)
                            .foregroundStyle(Color.textBody)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
        }
    }
}
