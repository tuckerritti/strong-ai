import Foundation
import SwiftData

// Shorthand for seed data readability
private func tm(_ muscle: String, _ weight: Double) -> TargetMuscle {
    TargetMuscle(muscle: muscle, weight: weight)
}

enum SeedData {
    static func clearAll(_ context: ModelContext) {
        try? context.delete(model: Exercise.self)
        try? context.delete(model: WorkoutLog.self)
        try? context.delete(model: UserProfile.self)
    }

    static func populate(_ context: ModelContext) {
        // MARK: - Exercises

        let exercises = [
            Exercise(name: "Bench Press", muscleGroup: "Chest",
                     exerciseDescription: "Barbell flat bench press",
                     instructions: ["Lie on bench with eyes under bar", "Grip bar slightly wider than shoulders", "Lower to mid-chest, press up"],
                     targetMuscles: [tm("chest", 0.6), tm("front-deltoid", 0.2), tm("triceps", 0.2)]),
            Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest",
                     exerciseDescription: "Dumbbell press on 30-45° incline",
                     instructions: ["Set bench to 30-45°", "Press dumbbells from shoulder level", "Lower with control"],
                     targetMuscles: [tm("upper-chest", 0.5), tm("front-deltoid", 0.25), tm("triceps", 0.25)]),
            Exercise(name: "Overhead Press", muscleGroup: "Shoulders",
                     exerciseDescription: "Standing barbell overhead press",
                     instructions: ["Grip bar at shoulder width", "Press overhead to lockout", "Keep core braced throughout"],
                     targetMuscles: [tm("deltoids", 0.6), tm("triceps", 0.25), tm("upper-trapezius", 0.15)]),
            Exercise(name: "Lateral Raise", muscleGroup: "Shoulders",
                     exerciseDescription: "Dumbbell lateral raise for side delts",
                     instructions: ["Hold dumbbells at sides", "Raise to shoulder height with slight bend in elbows", "Lower slowly"],
                     targetMuscles: [tm("deltoids", 1.0)]),
            Exercise(name: "Barbell Row", muscleGroup: "Back",
                     exerciseDescription: "Bent-over barbell row",
                     instructions: ["Hinge at hips, back flat", "Pull bar to lower chest", "Squeeze shoulder blades at top"],
                     targetMuscles: [tm("upper-back", 0.4), tm("rhomboids", 0.25), tm("biceps", 0.2), tm("rear-deltoid", 0.15)]),
            Exercise(name: "Pull-Up", muscleGroup: "Back",
                     exerciseDescription: "Bodyweight pull-up",
                     instructions: ["Hang with palms facing away", "Pull chin over bar", "Lower with control"],
                     targetMuscles: [tm("upper-back", 0.5), tm("biceps", 0.3), tm("forearm", 0.2)]),
            Exercise(name: "Squat", muscleGroup: "Legs",
                     exerciseDescription: "Barbell back squat",
                     instructions: ["Bar on upper back, feet shoulder width", "Squat to parallel or below", "Drive through heels to stand"],
                     targetMuscles: [tm("quadriceps", 0.5), tm("gluteal", 0.35), tm("lower-back", 0.15)]),
            Exercise(name: "Romanian Deadlift", muscleGroup: "Legs",
                     exerciseDescription: "Barbell Romanian deadlift for hamstrings",
                     instructions: ["Hold bar at hip level", "Hinge at hips, slight knee bend", "Lower until stretch in hamstrings, return to top"],
                     targetMuscles: [tm("hamstring", 0.5), tm("gluteal", 0.3), tm("lower-back", 0.2)]),
            Exercise(name: "Tricep Pushdown", muscleGroup: "Triceps",
                     exerciseDescription: "Cable tricep pushdown",
                     instructions: ["Grip cable attachment at chest height", "Extend arms fully", "Keep elbows pinned to sides"],
                     targetMuscles: [tm("triceps", 1.0)]),
            Exercise(name: "Barbell Curl", muscleGroup: "Biceps",
                     exerciseDescription: "Standing barbell curl",
                     instructions: ["Grip bar at shoulder width", "Curl to shoulder height", "Lower with control, no swinging"],
                     targetMuscles: [tm("biceps", 0.75), tm("forearm", 0.25)]),
            Exercise(name: "Leg Press", muscleGroup: "Quads",
                     exerciseDescription: "Machine leg press",
                     instructions: ["Sit in leg press machine", "Lower sled with control", "Press through heels to extend"],
                     targetMuscles: [tm("quadriceps", 0.65), tm("gluteal", 0.35)]),
            Exercise(name: "Leg Curl", muscleGroup: "Hamstrings",
                     exerciseDescription: "Lying leg curl machine",
                     instructions: ["Lie face down on machine", "Curl pad toward glutes", "Lower with control"],
                     targetMuscles: [tm("hamstring", 1.0)]),
            Exercise(name: "Hip Thrust", muscleGroup: "Glutes",
                     exerciseDescription: "Barbell hip thrust",
                     instructions: ["Sit with upper back on bench", "Roll bar over hips", "Drive hips up, squeeze at top"],
                     targetMuscles: [tm("gluteal", 0.7), tm("hamstring", 0.3)]),
            Exercise(name: "Calf Raise", muscleGroup: "Calves",
                     exerciseDescription: "Standing calf raise",
                     instructions: ["Stand on edge of platform", "Rise onto toes", "Lower slowly past parallel"],
                     targetMuscles: [tm("calves", 1.0)]),
            Exercise(name: "Barbell Shrug", muscleGroup: "Traps",
                     exerciseDescription: "Barbell shrug for upper traps",
                     instructions: ["Hold bar at hip level", "Shrug shoulders toward ears", "Hold at top, lower slowly"],
                     targetMuscles: [tm("trapezius", 0.5), tm("upper-trapezius", 0.5)]),
            Exercise(name: "Wrist Curl", muscleGroup: "Forearms",
                     exerciseDescription: "Seated barbell wrist curl",
                     instructions: ["Rest forearms on thighs", "Curl bar up using wrists only", "Lower slowly"],
                     targetMuscles: [tm("forearm", 1.0)]),
            Exercise(name: "Cable Crunch", muscleGroup: "Core",
                     exerciseDescription: "Kneeling cable crunch",
                     instructions: ["Kneel facing cable machine", "Crunch down bringing elbows to knees", "Return with control"],
                     targetMuscles: [tm("abs", 1.0)]),
        ]

        for exercise in exercises {
            context.insert(exercise)
        }

        // MARK: - User Profile

        let profile = UserProfile(
            goals: "Build muscle, improve strength",
            schedule: "4 days per week, 60 minute sessions",
            equipment: "Full gym — barbell, dumbbells, cables, pull-up bar",
            injuries: ""
        )
        context.insert(profile)

        // MARK: - Workout Logs (8 workouts over ~4 weeks)

        let now = Date.now
        func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(Double(-days) * 86400) }
        func minutesAfter(_ date: Date, _ minutes: Int) -> Date { date.addingTimeInterval(Double(minutes) * 60) }

        let logs: [(String, Int, [LogEntry])] = [
            // Week 4 (oldest)
            ("Upper Body Push", 25, [
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: [tm("chest", 0.6), tm("front-deltoid", 0.2), tm("triceps", 0.2)], sets: [
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 7, weight: 125, rpe: 9, completedAt: daysAgo(25)),
                ]),
                LogEntry(exerciseName: "Overhead Press", muscleGroup: "Shoulders", targetMuscles: [tm("deltoids", 0.6), tm("triceps", 0.25), tm("upper-trapezius", 0.15)], sets: [
                    LogSet(reps: 10, weight: 55, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 10, weight: 55, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 9, weight: 55, rpe: 9, completedAt: daysAgo(25)),
                ]),
                LogEntry(exerciseName: "Tricep Pushdown", muscleGroup: "Triceps", targetMuscles: [tm("triceps", 1.0)], sets: [
                    LogSet(reps: 15, weight: 25, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 15, weight: 25, rpe: 7, completedAt: daysAgo(25)),
                ]),
            ]),
            ("Upper Body Pull", 23, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.4), tm("rhomboids", 0.25), tm("biceps", 0.2), tm("rear-deltoid", 0.15)], sets: [
                    LogSet(reps: 8, weight: 115, rpe: 7, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.5), tm("biceps", 0.3), tm("forearm", 0.2)], sets: [
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                    LogSet(reps: 6, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: [tm("biceps", 0.75), tm("forearm", 0.25)], sets: [
                    LogSet(reps: 12, weight: 45, rpe: 7, completedAt: daysAgo(23)),
                    LogSet(reps: 12, weight: 45, rpe: 7, completedAt: daysAgo(23)),
                ]),
            ]),
            // Week 3
            ("Lower Body", 18, [
                LogEntry(exerciseName: "Squat", muscleGroup: "Legs", targetMuscles: [tm("quadriceps", 0.5), tm("gluteal", 0.35), tm("lower-back", 0.15)], sets: [
                    LogSet(reps: 8, weight: 155, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 8, weight: 155, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 7, weight: 155, rpe: 9, completedAt: daysAgo(18)),
                ]),
                LogEntry(exerciseName: "Romanian Deadlift", muscleGroup: "Legs", targetMuscles: [tm("hamstring", 0.5), tm("gluteal", 0.3), tm("lower-back", 0.2)], sets: [
                    LogSet(reps: 10, weight: 115, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                ]),
            ]),
            ("Upper Body Push", 16, [
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: [tm("chest", 0.6), tm("front-deltoid", 0.2), tm("triceps", 0.2)], sets: [
                    LogSet(reps: 8, weight: 130, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                ]),
                LogEntry(exerciseName: "Incline Dumbbell Press", muscleGroup: "Chest", targetMuscles: [tm("upper-chest", 0.5), tm("front-deltoid", 0.25), tm("triceps", 0.25)], sets: [
                    LogSet(reps: 10, weight: 40, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                ]),
                LogEntry(exerciseName: "Lateral Raise", muscleGroup: "Shoulders", targetMuscles: [tm("deltoids", 1.0)], sets: [
                    LogSet(reps: 15, weight: 15, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 15, weight: 15, rpe: 7, completedAt: daysAgo(16)),
                ]),
            ]),
            // Week 2
            ("Upper Body Pull", 11, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.4), tm("rhomboids", 0.25), tm("biceps", 0.2), tm("rear-deltoid", 0.15)], sets: [
                    LogSet(reps: 8, weight: 120, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.5), tm("biceps", 0.3), tm("forearm", 0.2)], sets: [
                    LogSet(reps: 9, weight: 0, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(11)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: [tm("biceps", 0.75), tm("forearm", 0.25)], sets: [
                    LogSet(reps: 12, weight: 50, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 12, weight: 50, rpe: 7, completedAt: daysAgo(11)),
                ]),
            ]),
            ("Lower Body", 9, [
                LogEntry(exerciseName: "Squat", muscleGroup: "Legs", targetMuscles: [tm("quadriceps", 0.5), tm("gluteal", 0.35), tm("lower-back", 0.15)], sets: [
                    LogSet(reps: 8, weight: 165, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 8, weight: 165, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 7, weight: 165, rpe: 9, completedAt: daysAgo(9)),
                ]),
                LogEntry(exerciseName: "Romanian Deadlift", muscleGroup: "Legs", targetMuscles: [tm("hamstring", 0.5), tm("gluteal", 0.3), tm("lower-back", 0.2)], sets: [
                    LogSet(reps: 10, weight: 125, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 9, completedAt: daysAgo(9)),
                ]),
            ]),
            // Week 1 (most recent)
            ("Upper Body Push", 4, [
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: [tm("chest", 0.6), tm("front-deltoid", 0.2), tm("triceps", 0.2)], sets: [
                    LogSet(reps: 8, weight: 135, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                ]),
                LogEntry(exerciseName: "Overhead Press", muscleGroup: "Shoulders", targetMuscles: [tm("deltoids", 0.6), tm("triceps", 0.25), tm("upper-trapezius", 0.15)], sets: [
                    LogSet(reps: 10, weight: 65, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 10, weight: 65, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 9, weight: 65, rpe: 9, completedAt: daysAgo(4)),
                ]),
                LogEntry(exerciseName: "Tricep Pushdown", muscleGroup: "Triceps", targetMuscles: [tm("triceps", 1.0)], sets: [
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(4)),
                ]),
            ]),
            ("Upper Body Pull", 2, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.4), tm("rhomboids", 0.25), tm("biceps", 0.2), tm("rear-deltoid", 0.15)], sets: [
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(2)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: [tm("upper-back", 0.5), tm("biceps", 0.3), tm("forearm", 0.2)], sets: [
                    LogSet(reps: 10, weight: 0, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 9, weight: 0, rpe: 8, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 0, rpe: 9, completedAt: daysAgo(2)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: [tm("biceps", 0.75), tm("forearm", 0.25)], sets: [
                    LogSet(reps: 12, weight: 55, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 12, weight: 55, rpe: 7, completedAt: daysAgo(2)),
                ]),
            ]),
            ("Lower Body", 3, [
                LogEntry(exerciseName: "Leg Press", muscleGroup: "Quads", targetMuscles: [tm("quadriceps", 0.65), tm("gluteal", 0.35)], sets: [
                    LogSet(reps: 10, weight: 200, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Leg Curl", muscleGroup: "Hamstrings", targetMuscles: [tm("hamstring", 1.0)], sets: [
                    LogSet(reps: 12, weight: 60, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 12, weight: 60, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Hip Thrust", muscleGroup: "Glutes", targetMuscles: [tm("gluteal", 0.7), tm("hamstring", 0.3)], sets: [
                    LogSet(reps: 10, weight: 135, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Calf Raise", muscleGroup: "Calves", targetMuscles: [tm("calves", 1.0)], sets: [
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, rpe: 7, completedAt: daysAgo(3)),
                ]),
            ]),
            ("Accessories", 1, [
                LogEntry(exerciseName: "Barbell Shrug", muscleGroup: "Traps", targetMuscles: [tm("trapezius", 0.5), tm("upper-trapezius", 0.5)], sets: [
                    LogSet(reps: 12, weight: 135, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                ]),
                LogEntry(exerciseName: "Wrist Curl", muscleGroup: "Forearms", targetMuscles: [tm("forearm", 1.0)], sets: [
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 15, weight: 30, rpe: 7, completedAt: daysAgo(1)),
                ]),
                LogEntry(exerciseName: "Cable Crunch", muscleGroup: "Core", targetMuscles: [tm("abs", 1.0)], sets: [
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
    }
}
