import Foundation
import SwiftData

enum SeedData {
    static func clearAll(_ context: ModelContext) {
        try? context.delete(model: Exercise.self)
        try? context.delete(model: WorkoutLog.self)
    }

    static func populate(_ context: ModelContext) {
        // MARK: - Exercises

        let exercises = [
            Exercise(name: "Bench Press", muscleGroup: "Chest",
                     exerciseDescription: "Barbell flat bench press",
                     instructions: ["Lie on bench with eyes under bar", "Grip bar slightly wider than shoulders", "Lower to mid-chest, press up"],
                     targetMuscles: ["chest", "front-deltoid", "triceps"]),
            Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest",
                     exerciseDescription: "Dumbbell press on 30-45° incline",
                     instructions: ["Set bench to 30-45°", "Press dumbbells from shoulder level", "Lower with control"],
                     targetMuscles: ["upper-chest", "front-deltoid", "triceps"]),
            Exercise(name: "Overhead Press", muscleGroup: "Shoulders",
                     exerciseDescription: "Standing barbell overhead press",
                     instructions: ["Grip bar at shoulder width", "Press overhead to lockout", "Keep core braced throughout"],
                     targetMuscles: ["deltoids", "triceps", "upper-trapezius"]),
            Exercise(name: "Lateral Raise", muscleGroup: "Shoulders",
                     exerciseDescription: "Dumbbell lateral raise for side delts",
                     instructions: ["Hold dumbbells at sides", "Raise to shoulder height with slight bend in elbows", "Lower slowly"],
                     targetMuscles: ["deltoids"]),
            Exercise(name: "Barbell Row", muscleGroup: "Back",
                     exerciseDescription: "Bent-over barbell row",
                     instructions: ["Hinge at hips, back flat", "Pull bar to lower chest", "Squeeze shoulder blades at top"],
                     targetMuscles: ["upper-back", "rhomboids", "biceps", "rear-deltoid"]),
            Exercise(name: "Pull-Up", muscleGroup: "Back",
                     exerciseDescription: "Bodyweight pull-up",
                     instructions: ["Hang with palms facing away", "Pull chin over bar", "Lower with control"],
                     targetMuscles: ["upper-back", "biceps", "forearm"]),
            Exercise(name: "Squat", muscleGroup: "Legs",
                     exerciseDescription: "Barbell back squat",
                     instructions: ["Bar on upper back, feet shoulder width", "Squat to parallel or below", "Drive through heels to stand"],
                     targetMuscles: ["quadriceps", "gluteal", "lower-back"]),
            Exercise(name: "Romanian Deadlift", muscleGroup: "Legs",
                     exerciseDescription: "Barbell Romanian deadlift for hamstrings",
                     instructions: ["Hold bar at hip level", "Hinge at hips, slight knee bend", "Lower until stretch in hamstrings, return to top"],
                     targetMuscles: ["hamstring", "gluteal", "lower-back"]),
            Exercise(name: "Tricep Pushdown", muscleGroup: "Triceps",
                     exerciseDescription: "Cable tricep pushdown",
                     instructions: ["Grip cable attachment at chest height", "Extend arms fully", "Keep elbows pinned to sides"],
                     targetMuscles: ["triceps"]),
            Exercise(name: "Barbell Curl", muscleGroup: "Biceps",
                     exerciseDescription: "Standing barbell curl",
                     instructions: ["Grip bar at shoulder width", "Curl to shoulder height", "Lower with control, no swinging"],
                     targetMuscles: ["biceps", "forearm"]),
            Exercise(name: "Leg Press", muscleGroup: "Quads",
                     exerciseDescription: "Machine leg press",
                     instructions: ["Sit in leg press machine", "Lower sled with control", "Press through heels to extend"],
                     targetMuscles: ["quadriceps", "gluteal"]),
            Exercise(name: "Leg Curl", muscleGroup: "Hamstrings",
                     exerciseDescription: "Lying leg curl machine",
                     instructions: ["Lie face down on machine", "Curl pad toward glutes", "Lower with control"],
                     targetMuscles: ["hamstring"]),
            Exercise(name: "Hip Thrust", muscleGroup: "Glutes",
                     exerciseDescription: "Barbell hip thrust",
                     instructions: ["Sit with upper back on bench", "Roll bar over hips", "Drive hips up, squeeze at top"],
                     targetMuscles: ["gluteal", "hamstring"]),
            Exercise(name: "Calf Raise", muscleGroup: "Calves",
                     exerciseDescription: "Standing calf raise",
                     instructions: ["Stand on edge of platform", "Rise onto toes", "Lower slowly past parallel"],
                     targetMuscles: ["calves"]),
            Exercise(name: "Barbell Shrug", muscleGroup: "Traps",
                     exerciseDescription: "Barbell shrug for upper traps",
                     instructions: ["Hold bar at hip level", "Shrug shoulders toward ears", "Hold at top, lower slowly"],
                     targetMuscles: ["trapezius", "upper-trapezius"]),
            Exercise(name: "Wrist Curl", muscleGroup: "Forearms",
                     exerciseDescription: "Seated barbell wrist curl",
                     instructions: ["Rest forearms on thighs", "Curl bar up using wrists only", "Lower slowly"],
                     targetMuscles: ["forearm"]),
            Exercise(name: "Cable Crunch", muscleGroup: "Core",
                     exerciseDescription: "Kneeling cable crunch",
                     instructions: ["Kneel facing cable machine", "Crunch down bringing elbows to knees", "Return with control"],
                     targetMuscles: ["abs"]),
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
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: ["chest", "front-deltoid", "triceps"], sets: [
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 7, weight: 125, rpe: 9, completedAt: daysAgo(25)),
                ]),
                LogEntry(exerciseName: "Overhead Press", muscleGroup: "Shoulders", targetMuscles: ["deltoids", "triceps", "upper-trapezius"], sets: [
                    LogSet(reps: 10, weight: 55, rpe: 7, completedAt: daysAgo(25)),
                    LogSet(reps: 10, weight: 55, rpe: 8, completedAt: daysAgo(25)),
                    LogSet(reps: 9, weight: 55, rpe: 9, completedAt: daysAgo(25)),
                ]),
                LogEntry(exerciseName: "Tricep Pushdown", muscleGroup: "Triceps", targetMuscles: ["triceps"], sets: [
                    LogSet(reps: 15, weight: 25, completedAt: daysAgo(25)),
                    LogSet(reps: 15, weight: 25, completedAt: daysAgo(25)),
                ]),
            ]),
            ("Upper Body Pull", 23, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: ["upper-back", "rhomboids", "biceps", "rear-deltoid"], sets: [
                    LogSet(reps: 8, weight: 115, rpe: 7, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 8, weight: 115, rpe: 8, completedAt: daysAgo(23)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: ["upper-back", "biceps", "forearm"], sets: [
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(23)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                    LogSet(reps: 6, weight: 0, rpe: 9, completedAt: daysAgo(23)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: ["biceps", "forearm"], sets: [
                    LogSet(reps: 12, weight: 45, completedAt: daysAgo(23)),
                    LogSet(reps: 12, weight: 45, completedAt: daysAgo(23)),
                ]),
            ]),
            // Week 3
            ("Lower Body", 18, [
                LogEntry(exerciseName: "Squat", muscleGroup: "Legs", targetMuscles: ["quadriceps", "gluteal", "lower-back"], sets: [
                    LogSet(reps: 8, weight: 155, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 8, weight: 155, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 7, weight: 155, rpe: 9, completedAt: daysAgo(18)),
                ]),
                LogEntry(exerciseName: "Romanian Deadlift", muscleGroup: "Legs", targetMuscles: ["hamstring", "gluteal", "lower-back"], sets: [
                    LogSet(reps: 10, weight: 115, rpe: 7, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                    LogSet(reps: 10, weight: 115, rpe: 8, completedAt: daysAgo(18)),
                ]),
            ]),
            ("Upper Body Push", 16, [
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: ["chest", "front-deltoid", "triceps"], sets: [
                    LogSet(reps: 8, weight: 130, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 8, weight: 130, rpe: 8, completedAt: daysAgo(16)),
                ]),
                LogEntry(exerciseName: "Incline Dumbbell Press", muscleGroup: "Chest", targetMuscles: ["upper-chest", "front-deltoid", "triceps"], sets: [
                    LogSet(reps: 10, weight: 40, rpe: 7, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                    LogSet(reps: 10, weight: 40, rpe: 8, completedAt: daysAgo(16)),
                ]),
                LogEntry(exerciseName: "Lateral Raise", muscleGroup: "Shoulders", targetMuscles: ["deltoids"], sets: [
                    LogSet(reps: 15, weight: 15, completedAt: daysAgo(16)),
                    LogSet(reps: 15, weight: 15, completedAt: daysAgo(16)),
                ]),
            ]),
            // Week 2
            ("Upper Body Pull", 11, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: ["upper-back", "rhomboids", "biceps", "rear-deltoid"], sets: [
                    LogSet(reps: 8, weight: 120, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 120, rpe: 8, completedAt: daysAgo(11)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: ["upper-back", "biceps", "forearm"], sets: [
                    LogSet(reps: 9, weight: 0, rpe: 7, completedAt: daysAgo(11)),
                    LogSet(reps: 8, weight: 0, rpe: 8, completedAt: daysAgo(11)),
                    LogSet(reps: 7, weight: 0, rpe: 9, completedAt: daysAgo(11)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: ["biceps", "forearm"], sets: [
                    LogSet(reps: 12, weight: 50, completedAt: daysAgo(11)),
                    LogSet(reps: 12, weight: 50, completedAt: daysAgo(11)),
                ]),
            ]),
            ("Lower Body", 9, [
                LogEntry(exerciseName: "Squat", muscleGroup: "Legs", targetMuscles: ["quadriceps", "gluteal", "lower-back"], sets: [
                    LogSet(reps: 8, weight: 165, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 8, weight: 165, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 7, weight: 165, rpe: 9, completedAt: daysAgo(9)),
                ]),
                LogEntry(exerciseName: "Romanian Deadlift", muscleGroup: "Legs", targetMuscles: ["hamstring", "gluteal", "lower-back"], sets: [
                    LogSet(reps: 10, weight: 125, rpe: 7, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 8, completedAt: daysAgo(9)),
                    LogSet(reps: 10, weight: 125, rpe: 9, completedAt: daysAgo(9)),
                ]),
            ]),
            // Week 1 (most recent)
            ("Upper Body Push", 4, [
                LogEntry(exerciseName: "Bench Press", muscleGroup: "Chest", targetMuscles: ["chest", "front-deltoid", "triceps"], sets: [
                    LogSet(reps: 8, weight: 135, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 8, weight: 135, rpe: 8, completedAt: daysAgo(4)),
                ]),
                LogEntry(exerciseName: "Overhead Press", muscleGroup: "Shoulders", targetMuscles: ["deltoids", "triceps", "upper-trapezius"], sets: [
                    LogSet(reps: 10, weight: 65, rpe: 7, completedAt: daysAgo(4)),
                    LogSet(reps: 10, weight: 65, rpe: 8, completedAt: daysAgo(4)),
                    LogSet(reps: 9, weight: 65, rpe: 9, completedAt: daysAgo(4)),
                ]),
                LogEntry(exerciseName: "Tricep Pushdown", muscleGroup: "Triceps", targetMuscles: ["triceps"], sets: [
                    LogSet(reps: 15, weight: 30, completedAt: daysAgo(4)),
                    LogSet(reps: 15, weight: 30, completedAt: daysAgo(4)),
                ]),
            ]),
            ("Upper Body Pull", 2, [
                LogEntry(exerciseName: "Barbell Row", muscleGroup: "Back", targetMuscles: ["upper-back", "rhomboids", "biceps", "rear-deltoid"], sets: [
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 125, rpe: 8, completedAt: daysAgo(2)),
                ]),
                LogEntry(exerciseName: "Pull-Up", muscleGroup: "Back", targetMuscles: ["upper-back", "biceps", "forearm"], sets: [
                    LogSet(reps: 10, weight: 0, rpe: 7, completedAt: daysAgo(2)),
                    LogSet(reps: 9, weight: 0, rpe: 8, completedAt: daysAgo(2)),
                    LogSet(reps: 8, weight: 0, rpe: 9, completedAt: daysAgo(2)),
                ]),
                LogEntry(exerciseName: "Barbell Curl", muscleGroup: "Biceps", targetMuscles: ["biceps", "forearm"], sets: [
                    LogSet(reps: 12, weight: 55, completedAt: daysAgo(2)),
                    LogSet(reps: 12, weight: 55, completedAt: daysAgo(2)),
                ]),
            ]),
            ("Lower Body", 3, [
                LogEntry(exerciseName: "Leg Press", muscleGroup: "Quads", targetMuscles: ["quadriceps", "gluteal"], sets: [
                    LogSet(reps: 10, weight: 200, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 200, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Leg Curl", muscleGroup: "Hamstrings", targetMuscles: ["hamstring"], sets: [
                    LogSet(reps: 12, weight: 60, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 12, weight: 60, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Hip Thrust", muscleGroup: "Glutes", targetMuscles: ["gluteal", "hamstring"], sets: [
                    LogSet(reps: 10, weight: 135, rpe: 7, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                    LogSet(reps: 10, weight: 135, rpe: 8, completedAt: daysAgo(3)),
                ]),
                LogEntry(exerciseName: "Calf Raise", muscleGroup: "Calves", targetMuscles: ["calves"], sets: [
                    LogSet(reps: 15, weight: 90, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, completedAt: daysAgo(3)),
                    LogSet(reps: 15, weight: 90, completedAt: daysAgo(3)),
                ]),
            ]),
            ("Accessories", 1, [
                LogEntry(exerciseName: "Barbell Shrug", muscleGroup: "Traps", targetMuscles: ["trapezius", "upper-trapezius"], sets: [
                    LogSet(reps: 12, weight: 135, rpe: 7, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                    LogSet(reps: 12, weight: 135, rpe: 8, completedAt: daysAgo(1)),
                ]),
                LogEntry(exerciseName: "Wrist Curl", muscleGroup: "Forearms", targetMuscles: ["forearm"], sets: [
                    LogSet(reps: 15, weight: 30, completedAt: daysAgo(1)),
                    LogSet(reps: 15, weight: 30, completedAt: daysAgo(1)),
                ]),
                LogEntry(exerciseName: "Cable Crunch", muscleGroup: "Core", targetMuscles: ["abs"], sets: [
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
