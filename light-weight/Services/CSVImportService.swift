import Foundation
import MuscleMap
import SwiftData

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

enum CSVColumnRole: String, CaseIterable, Identifiable {
    case exerciseName = "Exercise Name"
    case weight = "Weight"
    case reps = "Reps"
    case rpe = "RPE"
    case date = "Date"
    case workoutName = "Workout Name"
    case skip = "Skip"

    var id: String { rawValue }
}

struct CSVImportResult {
    var workoutCount: Int
    var unclassifiedExerciseNames: [String]
}

enum CSVImportService {

    // MARK: - Parsing

    static func parse(_ text: String) -> (headers: [String], rows: [[String]]) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { return ([], []) }

        let headers = parseCSVLine(headerLine)
        let rows = lines.dropFirst().map { parseCSVLine($0) }
        return (headers, rows)
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Auto-mapping

    static func suggestMapping(headers: [String]) -> [CSVColumnRole] {
        var used: Set<CSVColumnRole> = []
        return headers.map { header in
            let lower = header.lowercased()
            let role: CSVColumnRole
            if lower.contains("exercise") { role = .exerciseName }
            else if lower.contains("weight") { role = .weight }
            else if lower.contains("rep") { role = .reps }
            else if lower.contains("rpe") { role = .rpe }
            else if lower.contains("date") { role = .date }
            else if lower.contains("workout") { role = .workoutName }
            else { return .skip }

            guard !used.contains(role) else { return .skip }
            used.insert(role)
            return role
        }
    }

    // MARK: - Import

    static func importWorkouts(
        rows: [[String]],
        mapping: [CSVColumnRole],
        existingExercises: [Exercise],
        modelContext: ModelContext
    ) -> CSVImportResult {
        let index = columnIndex(from: mapping)
        let exerciseLookup = Dictionary(
            existingExercises.map { ($0.name.lowercased().trimmingCharacters(in: .whitespaces), (muscleGroup: $0.muscleGroup, targetMuscles: $0.targetMuscles)) },
            uniquingKeysWith: { first, _ in first }
        )

        // Group rows into workout sessions by (date string, workout name)
        var sessions: [(key: String, rows: [[String]])] = []
        var sessionMap: [String: Int] = [:]

        for row in rows {
            guard let dateStr = value(row, index[.date]), parseDate(dateStr) != nil else { continue }
            let name = value(row, index[.workoutName]) ?? "Imported Workout"
            let key = "\(dateStr)|\(name)"

            if let idx = sessionMap[key] {
                sessions[idx].rows.append(row)
            } else {
                sessionMap[key] = sessions.count
                sessions.append((key: key, rows: [row]))
            }
        }

        var allExerciseNames: [(name: String, muscleGroup: String)] = []
        var unclassifiedNames = Set<String>()

        for session in sessions {
            let firstRow = session.rows[0]
            let workoutDate = parseDate(value(firstRow, index[.date]))!
            let workoutName = value(firstRow, index[.workoutName]) ?? "Imported Workout"

            // Group rows by exercise name, preserving order
            var exerciseOrder: [String] = []
            var exerciseRows: [String: [[String]]] = [:]

            for row in session.rows {
                // Strong app CSV exports include "Rest Timer" in the Set Order column — skip them
                if row.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "Rest Timer" }) { continue }

                let exerciseName = value(row, index[.exerciseName]) ?? "Unknown Exercise"

                if exerciseRows[exerciseName] == nil {
                    exerciseOrder.append(exerciseName)
                }
                exerciseRows[exerciseName, default: []].append(row)
            }

            let entries: [LogEntry] = exerciseOrder.map { exerciseName in
                let rows = exerciseRows[exerciseName]!
                let key = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
                let match = exerciseLookup[key]
                let muscleGroup = match?.muscleGroup ?? "Other"
                let targetMuscles = match?.targetMuscles ?? []

                if match == nil {
                    unclassifiedNames.insert(exerciseName)
                }

                let sets: [LogSet] = rows.map { row in
                    LogSet(
                        reps: Int(Double(value(row, index[.reps]) ?? "0") ?? 0),
                        weight: Double(value(row, index[.weight]) ?? "0") ?? 0,
                        rpe: Int(Double(value(row, index[.rpe]) ?? "0") ?? 0),
                        completedAt: workoutDate
                    )
                }

                allExerciseNames.append((name: exerciseName, muscleGroup: muscleGroup))
                return LogEntry(exerciseName: exerciseName, muscleGroup: muscleGroup, targetMuscles: targetMuscles, sets: sets)
            }

            let log = WorkoutLog(workoutName: workoutName, entries: entries, startedAt: workoutDate)
            log.finishedAt = workoutDate
            modelContext.insert(log)
        }

        // Persist new exercises to library
        var knownNames = Set(existingExercises.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        for (name, muscleGroup) in allExerciseNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.lowercased()
            guard !normalizedName.isEmpty, !muscleGroup.isEmpty else { continue }
            guard knownNames.insert(normalizedName).inserted else { continue }
            modelContext.insert(Exercise(name: trimmedName, muscleGroup: muscleGroup))
        }

        return CSVImportResult(
            workoutCount: sessions.count,
            unclassifiedExerciseNames: Array(unclassifiedNames)
        )
    }

    // MARK: - Exercise Classification

    static func classifyExercises(
        names: [String],
        apiKey: String,
        exercises: [Exercise],
        workoutLogs: [WorkoutLog],
        modelContext: ModelContext
    ) async throws {
        let systemPrompt = """
        You are an exercise classification assistant. Given a list of exercise names, respond with ONLY valid JSON matching this schema:
        {"exercises": [{"name": "Exercise Name", "muscleGroup": "Muscle Group", "targetMuscles": [{"muscle": "chest", "weight": 0.6}], "description": "Brief one-line description", "instructions": ["Step 1", "Step 2"]}]}

        Guidelines:
        - muscleGroup: high-level grouping (e.g. "Chest", "Back", "Shoulders", "Legs", "Biceps", "Triceps", "Core")
        - targetMuscles: list muscles worked with a weight (0-1) representing that muscle's share of the work. Weights should sum to ~1.0.
        - Valid muscle values: \(Muscle.validPromptValues)
        - description: a short one-line description of the exercise.
        - instructions: step-by-step instructions for how to perform the exercise (3-5 concise steps).
        - Return the exercise name exactly as provided.
        """

        let api = ClaudeAPIService(apiKey: apiKey)
        var classificationMap: [String: ClassifiedExercise] = [:]

        // Batch into groups of 15 to avoid exceeding the token limit
        for batch in names.chunked(into: 15) {
            let nameList = batch.map { "- \($0)" }.joined(separator: "\n")
            let response = try await api.send(
                systemPrompt: systemPrompt,
                userMessage: "Classify these exercises:\n\(nameList)"
            )

            let jsonString = JSONExtractor.extractObject(from: response)
            guard let data = jsonString.data(using: .utf8) else { continue }
            let decoded = try JSONDecoder().decode(ClassificationResponse.self, from: data)

            for exercise in decoded.exercises {
                classificationMap[exercise.name.lowercased().trimmingCharacters(in: .whitespaces)] = exercise
            }
        }

        // Update Exercise library entries
        for exercise in exercises {
            let key = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
            guard let classification = classificationMap[key] else { continue }
            exercise.muscleGroup = classification.muscleGroup
            exercise.targetMuscles = classification.targetMuscles
            exercise.exerciseDescription = classification.description
            if let instructions = classification.instructions {
                exercise.instructions = instructions
            }
        }

        // Backfill WorkoutLog entries
        for log in workoutLogs {
            var entries = log.entries
            var modified = false
            for i in entries.indices {
                let key = entries[i].exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
                guard let classification = classificationMap[key] else { continue }
                entries[i].muscleGroup = classification.muscleGroup
                entries[i].targetMuscles = classification.targetMuscles
                modified = true
            }
            if modified {
                log.entries = entries
            }
        }
    }

    private struct ClassificationResponse: Decodable {
        var exercises: [ClassifiedExercise]
    }

    private struct ClassifiedExercise: Decodable {
        var name: String
        var muscleGroup: String
        var targetMuscles: [TargetMuscle]
        var description: String?
        var instructions: [String]?
    }

    // MARK: - Helpers

    private static func columnIndex(from mapping: [CSVColumnRole]) -> [CSVColumnRole: Int] {
        var result: [CSVColumnRole: Int] = [:]
        for (i, role) in mapping.enumerated() where role != .skip {
            if result[role] == nil { result[role] = i }
        }
        return result
    }

    private static func value(_ row: [String], _ index: Int?) -> String? {
        guard let index, index < row.count else { return nil }
        let val = row[index].trimmingCharacters(in: .whitespaces)
        return val.isEmpty ? nil : val
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
