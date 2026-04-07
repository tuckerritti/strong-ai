import Foundation
import SwiftData

// Shorthand for seed data readability
private func tm(_ muscle: String, _ weight: Double) -> TargetMuscle {
    TargetMuscle(muscle: muscle, weight: weight)
}

private struct SeedExercise {
    let name: String
    let muscleGroup: String
    let exerciseDescription: String
    let instructions: [String]
    let targetMuscles: [TargetMuscle]

    var model: Exercise {
        Exercise(
            name: name,
            muscleGroup: muscleGroup,
            exerciseDescription: exerciseDescription,
            instructions: instructions,
            targetMuscles: targetMuscles
        )
    }
}

enum SeedData {
    private static let exerciseSeeds: [SeedExercise] = [
        SeedExercise(
            name: "Bench Press",
            muscleGroup: "Chest",
            exerciseDescription: "Barbell flat bench press",
            instructions: [
                "Lie on bench with eyes under bar",
                "Grip bar slightly wider than shoulders",
                "Lower to mid-chest, press up",
            ],
            targetMuscles: [tm("chest", 0.6), tm("front-deltoid", 0.2), tm("triceps", 0.2)]
        ),
        SeedExercise(
            name: "Incline Dumbbell Press",
            muscleGroup: "Chest",
            exerciseDescription: "Dumbbell press on 30-45° incline",
            instructions: [
                "Set bench to 30-45°",
                "Press dumbbells from shoulder level",
                "Lower with control",
            ],
            targetMuscles: [tm("upper-chest", 0.5), tm("front-deltoid", 0.25), tm("triceps", 0.25)]
        ),
        SeedExercise(
            name: "Overhead Press",
            muscleGroup: "Shoulders",
            exerciseDescription: "Standing barbell overhead press",
            instructions: [
                "Grip bar at shoulder width",
                "Press overhead to lockout",
                "Keep core braced throughout",
            ],
            targetMuscles: [tm("deltoids", 0.6), tm("triceps", 0.25), tm("upper-trapezius", 0.15)]
        ),
        SeedExercise(
            name: "Lateral Raise",
            muscleGroup: "Shoulders",
            exerciseDescription: "Dumbbell lateral raise for side delts",
            instructions: [
                "Hold dumbbells at sides",
                "Raise to shoulder height with slight bend in elbows",
                "Lower slowly",
            ],
            targetMuscles: [tm("deltoids", 1.0)]
        ),
        SeedExercise(
            name: "Barbell Row",
            muscleGroup: "Back",
            exerciseDescription: "Bent-over barbell row",
            instructions: [
                "Hinge at hips, back flat",
                "Pull bar to lower chest",
                "Squeeze shoulder blades at top",
            ],
            targetMuscles: [tm("upper-back", 0.4), tm("rhomboids", 0.25), tm("biceps", 0.2), tm("rear-deltoid", 0.15)]
        ),
        SeedExercise(
            name: "Pull-Up",
            muscleGroup: "Back",
            exerciseDescription: "Bodyweight pull-up",
            instructions: [
                "Hang with palms facing away",
                "Pull chin over bar",
                "Lower with control",
            ],
            targetMuscles: [tm("upper-back", 0.5), tm("biceps", 0.3), tm("forearm", 0.2)]
        ),
        SeedExercise(
            name: "Squat",
            muscleGroup: "Legs",
            exerciseDescription: "Barbell back squat",
            instructions: [
                "Bar on upper back, feet shoulder width",
                "Squat to parallel or below",
                "Drive through heels to stand",
            ],
            targetMuscles: [tm("quadriceps", 0.5), tm("gluteal", 0.35), tm("lower-back", 0.15)]
        ),
        SeedExercise(
            name: "Romanian Deadlift",
            muscleGroup: "Legs",
            exerciseDescription: "Barbell Romanian deadlift for hamstrings",
            instructions: [
                "Hold bar at hip level",
                "Hinge at hips, slight knee bend",
                "Lower until stretch in hamstrings, return to top",
            ],
            targetMuscles: [tm("hamstring", 0.5), tm("gluteal", 0.3), tm("lower-back", 0.2)]
        ),
        SeedExercise(
            name: "Tricep Pushdown",
            muscleGroup: "Triceps",
            exerciseDescription: "Cable tricep pushdown",
            instructions: [
                "Grip cable attachment at chest height",
                "Extend arms fully",
                "Keep elbows pinned to sides",
            ],
            targetMuscles: [tm("triceps", 1.0)]
        ),
        SeedExercise(
            name: "Barbell Curl",
            muscleGroup: "Biceps",
            exerciseDescription: "Standing barbell curl",
            instructions: [
                "Grip bar at shoulder width",
                "Curl to shoulder height",
                "Lower with control, no swinging",
            ],
            targetMuscles: [tm("biceps", 0.75), tm("forearm", 0.25)]
        ),
        SeedExercise(
            name: "Leg Press",
            muscleGroup: "Quads",
            exerciseDescription: "Machine leg press",
            instructions: [
                "Sit in leg press machine",
                "Lower sled with control",
                "Press through heels to extend",
            ],
            targetMuscles: [tm("quadriceps", 0.65), tm("gluteal", 0.35)]
        ),
        SeedExercise(
            name: "Leg Curl",
            muscleGroup: "Hamstrings",
            exerciseDescription: "Lying leg curl machine",
            instructions: [
                "Lie face down on machine",
                "Curl pad toward glutes",
                "Lower with control",
            ],
            targetMuscles: [tm("hamstring", 1.0)]
        ),
        SeedExercise(
            name: "Hip Thrust",
            muscleGroup: "Glutes",
            exerciseDescription: "Barbell hip thrust",
            instructions: [
                "Sit with upper back on bench",
                "Roll bar over hips",
                "Drive hips up, squeeze at top",
            ],
            targetMuscles: [tm("gluteal", 0.7), tm("hamstring", 0.3)]
        ),
        SeedExercise(
            name: "Calf Raise",
            muscleGroup: "Calves",
            exerciseDescription: "Standing calf raise",
            instructions: [
                "Stand on edge of platform",
                "Rise onto toes",
                "Lower slowly past parallel",
            ],
            targetMuscles: [tm("calves", 1.0)]
        ),
        SeedExercise(
            name: "Barbell Shrug",
            muscleGroup: "Traps",
            exerciseDescription: "Barbell shrug for upper traps",
            instructions: [
                "Hold bar at hip level",
                "Shrug shoulders toward ears",
                "Hold at top, lower slowly",
            ],
            targetMuscles: [tm("trapezius", 0.5), tm("upper-trapezius", 0.5)]
        ),
        SeedExercise(
            name: "Wrist Curl",
            muscleGroup: "Forearms",
            exerciseDescription: "Seated barbell wrist curl",
            instructions: [
                "Rest forearms on thighs",
                "Curl bar up using wrists only",
                "Lower slowly",
            ],
            targetMuscles: [tm("forearm", 1.0)]
        ),
        SeedExercise(
            name: "Cable Crunch",
            muscleGroup: "Core",
            exerciseDescription: "Kneeling cable crunch",
            instructions: [
                "Kneel facing cable machine",
                "Crunch down bringing elbows to knees",
                "Return with control",
            ],
            targetMuscles: [tm("abs", 1.0)]
        ),
    ]

    private static let exerciseLookup = Dictionary(uniqueKeysWithValues: exerciseSeeds.map { ($0.name, $0) })

    private static func logEntry(_ exerciseName: String, sets: [LogSet], supersetGroupId: Int? = nil) -> LogEntry {
        guard let exercise = exerciseLookup[exerciseName] else {
            preconditionFailure("Missing seed exercise for log entry: \(exerciseName)")
        }

        return LogEntry(
            exerciseName: exercise.name,
            muscleGroup: exercise.muscleGroup,
            targetMuscles: exercise.targetMuscles,
            sets: sets,
            supersetGroupId: supersetGroupId
        )
    }

    static func clearAll(_ context: ModelContext) {
        try? context.delete(model: Exercise.self)
        try? context.delete(model: WorkoutLog.self)
        try? context.delete(model: UserProfile.self)
    }

    static func populate(_ context: ModelContext) {
        // MARK: - Exercises

        for exercise in exerciseSeeds {
            context.insert(exercise.model)
        }

        // MARK: - User Profile

        let profile = UserProfile(
            goals: "Build muscle, improve strength",
            schedule: "4 days per week, 60 minute sessions",
            equipment: "Full gym — barbell, dumbbells, cables, pull-up bar",
            injuries: "",
            gender: "Male",
            experienceLevel: "Intermediate",
            trainingDays: "[0,1,3,5]",
            onboardingCompleted: true,
            healthKitEnabled: true
        )
        context.insert(profile)

        // MARK: - Workout Logs (8 workouts over ~4 weeks)

        let now = Date.now
        func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(Double(-days) * 86400) }
        func minutesAfter(_ date: Date, _ minutes: Int) -> Date { date.addingTimeInterval(Double(minutes) * 60) }

        let logs: [(String, Int, [LogEntry])] = [
            // Week 4 (oldest)
            ("Upper Body Push", 25, [
                logEntry("Bench Press", sets: [
                    LogSet(reps: 10, weight: 65, rpe: 4, completedAt: daysAgo(25), isWarmup: true),
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 7, weight: 125, rpe: 9, completedAt: daysAgo(25)),
                ]),
                logEntry("Overhead Press", sets: [
                    LogSet(reps: 10, weight: 60, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 10, weight: 60, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 9, weight: 60, rpe: 9, completedAt: daysAgo(25)),
                ]),
                logEntry("Tricep Pushdown", sets: [
                    LogSet(reps: 15, weight: 25, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 15, weight: 25, rpe: 7, completedAt: daysAgo(25)),
                ]),
            ]),
            ("Upper Body Pull", 23, [
                logEntry("Barbell Row", sets: [
                    LogSet(reps: 8, weight: 115, rpe: 7, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                ]),
                logEntry("Pull-Up", sets: [
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                    LogSet(reps: 6, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                ]),
                logEntry("Barbell Curl", sets: [
                    LogSet(reps: 12, weight: 45, rpe: 7, completedAt: daysAgo(23)),
                    LogSet(reps: 12, weight: 45, rpe: 7, completedAt: daysAgo(23)),
                ]),
            ]),
            // Week 3
            ("Lower Body", 18, [
                logEntry("Squat", sets: [
                    LogSet(reps: 8, weight: 155, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 8, weight: 155, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 7, weight: 155, rpe: 9, completedAt: daysAgo(18)),
                ]),
                logEntry("Romanian Deadlift", sets: [
                    LogSet(reps: 10, weight: 115, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                ]),
            ]),
            ("Upper Body Push", 16, [
                logEntry("Bench Press", sets: [
                    LogSet(reps: 8, weight: 130, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                ]),
                logEntry("Incline Dumbbell Press", sets: [
                    LogSet(reps: 10, weight: 40, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                ]),
                logEntry("Lateral Raise", sets: [
                    LogSet(reps: 15, weight: 15, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 15, weight: 15, rpe: 7, completedAt: daysAgo(16)),
                ]),
            ]),
            // Week 2
            ("Upper Body Pull", 11, [
                logEntry("Barbell Row", sets: [
                    LogSet(reps: 8, weight: 120, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                ]),
                logEntry("Pull-Up", sets: [
                    LogSet(reps: 9, weight: 0, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(11)),
                ]),
                logEntry("Barbell Curl", sets: [
                    LogSet(reps: 12, weight: 50, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 12, weight: 50, rpe: 7, completedAt: daysAgo(11)),
                ]),
            ]),
            ("Lower Body", 9, [
                logEntry("Squat", sets: [
                    LogSet(reps: 8, weight: 165, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 8, weight: 165, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 7, weight: 165, rpe: 9, completedAt: daysAgo(9)),
                ]),
                logEntry("Romanian Deadlift", sets: [
                    LogSet(reps: 10, weight: 125, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 9, completedAt: daysAgo(9)),
                ]),
            ]),
            // Week 1 (most recent)
            ("Upper Body Push", 4, [
                logEntry("Bench Press", sets: [
                    LogSet(reps: 10, weight: 70, rpe: 4, completedAt: daysAgo(4), isWarmup: true),
                    LogSet(reps: 8, weight: 135, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                ]),
                logEntry("Overhead Press", sets: [
                    LogSet(reps: 10, weight: 65, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 10, weight: 65, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 9, weight: 65, rpe: 9, completedAt: daysAgo(4)),
                ]),
                logEntry("Tricep Pushdown", sets: [
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(4)),
                ]),
            ]),
            ("Upper Body Pull", 2, [
                logEntry("Barbell Row", sets: [
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(2)),
                ], supersetGroupId: 1),
                logEntry("Pull-Up", sets: [
                    LogSet(reps: 10, weight: 0, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 9, weight: 0, rpe: 8, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 0, rpe: 9, completedAt: daysAgo(2)),
                ], supersetGroupId: 1),
                logEntry("Barbell Curl", sets: [
                    LogSet(reps: 12, weight: 55, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 12, weight: 55, rpe: 7, completedAt: daysAgo(2)),
                ]),
            ]),
            ("Lower Body", 3, [
                logEntry("Leg Press", sets: [
                    LogSet(reps: 10, weight: 200, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                ]),
                logEntry("Leg Curl", sets: [
                    LogSet(reps: 12, weight: 60, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 12, weight: 60, rpe: 8, completedAt: daysAgo(3)),
                ]),
                logEntry("Hip Thrust", sets: [
                    LogSet(reps: 10, weight: 135, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                ]),
                logEntry("Calf Raise", sets: [
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                ]),
            ]),
            ("Accessories", 1, [
                logEntry("Barbell Shrug", sets: [
                    LogSet(reps: 12, weight: 135, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                ], supersetGroupId: 1),
                logEntry("Wrist Curl", sets: [
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(1)),
                ], supersetGroupId: 1),
                logEntry("Cable Crunch", sets: [
                    LogSet(reps: 15, weight: 50, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 15, weight: 50, rpe: 8, completedAt: daysAgo(1)),
                    LogSet(reps: 15, weight: 50, rpe: 8, completedAt: daysAgo(1)),
                ]),
            ]),
        ]

        for (name, daysBack, entries) in logs {
            let start = daysAgo(daysBack)
            let log = WorkoutLog(workoutName: name, entries: entries, startedAt: start)
            log.finishedAt = minutesAfter(start, 55)
            context.insert(log)
        }

        try? context.save()
    }
}
