import Foundation
import MuscleMap
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "CSVImportService")

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
        let allRows = parseCSVRows(text)
        guard let headers = allRows.first else {
            logger.info("csv_import parse_empty")
            return ([], [])
        }

        let rows = Array(allRows.dropFirst())
        if rows.isEmpty {
            logger.info("csv_import parse_empty")
        } else {
            logger.info("csv_import parse_success headers=\(headers.count, privacy: .public) rows=\(rows.count, privacy: .public)")
        }
        return (headers, rows)
    }

    /// RFC 4180-aware CSV parser that handles escaped quotes (`""`) and multiline quoted fields.
    private static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if inQuotes {
                if char == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\"" {
                        // Escaped quote ""
                        current.append("\"")
                        i = text.index(after: next)
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i = text.index(after: i)
                    }
                } else {
                    current.append(char)
                    i = text.index(after: i)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                    i = text.index(after: i)
                } else if char == "," {
                    fields.append(current)
                    current = ""
                    i = text.index(after: i)
                } else if char == "\r" || char == "\n" {
                    // Skip \r\n as a single line break
                    if char == "\r" {
                        let next = text.index(after: i)
                        if next < text.endIndex, text[next] == "\n" {
                            i = text.index(after: next)
                        } else {
                            i = text.index(after: i)
                        }
                    } else {
                        i = text.index(after: i)
                    }
                    fields.append(current)
                    current = ""
                    // Only add the row if it has content (skip blank lines)
                    if fields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        rows.append(fields)
                    }
                    fields = []
                } else {
                    current.append(char)
                    i = text.index(after: i)
                }
            }
        }

        // Flush last row
        fields.append(current)
        if fields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            rows.append(fields)
        }

        return rows
    }

    // MARK: - Auto-mapping

    static func suggestMapping(headers: [String]) -> [CSVColumnRole] {
        var used: Set<CSVColumnRole> = []
        let mapping: [CSVColumnRole] = headers.map { header in
            let lower = header.lowercased()
            let role: CSVColumnRole
            if lower.contains("exercise") { role = .exerciseName }
            else if lower.contains("weight") { role = .weight }
            else if lower.contains("rep") { role = .reps }
            else if lower.contains("rpe") { role = .rpe }
            else if lower.contains("date") || lower.contains("time") { role = .date }
            else if lower.contains("workout") || lower == "title" { role = .workoutName }
            else { return CSVColumnRole.skip }

            guard !used.contains(role) else { return CSVColumnRole.skip }
            used.insert(role)
            return role
        }
        let mappedCount = mapping.filter { $0 != CSVColumnRole.skip }.count
        logger.info(
            "csv_import mapping_suggested headers=\(headers.count, privacy: .public) mapped=\(mappedCount, privacy: .public) hasExerciseName=\(mapping.contains(.exerciseName), privacy: .public) hasDate=\(mapping.contains(.date), privacy: .public) hasWorkoutName=\(mapping.contains(.workoutName), privacy: .public)"
        )
        return mapping
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
        logger.info(
            "csv_import start rows=\(rows.count, privacy: .public) mappedColumns=\(mapping.filter { $0 != .skip }.count, privacy: .public) existingExercises=\(existingExercises.count, privacy: .public)"
        )

        // Group rows into workout sessions by (date string, workout name)
        var sessions: [(key: String, rows: [[String]])] = []
        var sessionMap: [String: Int] = [:]
        var invalidDateRowCount = 0
        var skippedRestTimerRowCount = 0

        for row in rows {
            guard let dateStr = value(row, index[.date]), parseDate(dateStr) != nil else {
                invalidDateRowCount += 1
                continue
            }
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
            guard let workoutDate = parseDate(value(firstRow, index[.date])) else { continue }
            let workoutName = value(firstRow, index[.workoutName]) ?? "Imported Workout"

            // Group rows by exercise name, preserving order
            var exerciseOrder: [String] = []
            var exerciseRows: [String: [[String]]] = [:]

            for row in session.rows {
                // Strong app CSV exports include "Rest Timer" in the Set Order column — skip them
                if row.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "Rest Timer" }) {
                    skippedRestTimerRowCount += 1
                    continue
                }

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
        var newExerciseCount = 0
        for (name, muscleGroup) in allExerciseNames {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.lowercased()
            guard !normalizedName.isEmpty, !muscleGroup.isEmpty else { continue }
            guard knownNames.insert(normalizedName).inserted else { continue }
            modelContext.insert(Exercise(name: trimmedName, muscleGroup: muscleGroup))
            newExerciseCount += 1
        }

        logger.info(
            "csv_import success workouts=\(sessions.count, privacy: .public) newExercises=\(newExerciseCount, privacy: .public) unclassifiedExercises=\(unclassifiedNames.count, privacy: .public) invalidDateRows=\(invalidDateRowCount, privacy: .public) skippedRestTimerRows=\(skippedRestTimerRowCount, privacy: .public)"
        )

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
        modelContext: ModelContext,
        onBatchComplete: (@MainActor (Int) -> Void)? = nil,
        onCost: @Sendable @escaping (TokenCost) -> Void = { _ in }
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

        let api = ClaudeAPIService(apiKey: apiKey, onCost: onCost)

        // Batch into groups of 15 to avoid exceeding the token limit
        let batches = names.chunked(into: 15)
        logger.info(
            "csv_import_classification start names=\(names.count, privacy: .public) batches=\(batches.count, privacy: .public) exercises=\(exercises.count, privacy: .public) logs=\(workoutLogs.count, privacy: .public)"
        )

        // Process batches with limited concurrency (max 3 in flight)
        let maxConcurrency = 3
        let classificationMap: [String: ClassifiedExercise] = try await withThrowingTaskGroup(
            of: [ClassifiedExercise].self
        ) { group in
            var batchIterator = batches.makeIterator()
            var inFlight = 0
            var result: [String: ClassifiedExercise] = [:]
            var completed = 0

            func addBatch(_ batch: [String]) {
                group.addTask {
                    let nameList = batch.map { "- \($0)" }.joined(separator: "\n")
                    let response = try await api.send(
                        operation: "classify-exercises",
                        systemPrompt: systemPrompt,
                        userMessage: "Classify these exercises:\n\(nameList)"
                    )

                    let jsonString = JSONExtractor.extractObject(from: response)
                    guard let data = jsonString.data(using: .utf8) else { return [] }
                    let decoded = try JSONDecoder().decode(ClassificationResponse.self, from: data)
                    return decoded.exercises
                }
                inFlight += 1
            }

            // Seed initial batch of tasks
            while inFlight < maxConcurrency, let batch = batchIterator.next() {
                addBatch(batch)
            }

            // As each completes, start the next
            for try await classified in group {
                inFlight -= 1
                for exercise in classified {
                    result[exercise.name.lowercased().trimmingCharacters(in: .whitespaces)] = exercise
                }
                completed += 1
                logger.info(
                    "csv_import_classification batch_success batch=\(completed, privacy: .public)/\(batches.count, privacy: .public) classified=\(classified.count, privacy: .public)"
                )
                let batchNum = completed
                await MainActor.run {
                    onBatchComplete?(batchNum)
                }

                if let batch = batchIterator.next() {
                    addBatch(batch)
                }
            }
            return result
        }

        // Update Exercise library entries
        var updatedExerciseCount = 0
        for exercise in exercises {
            let key = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
            guard let classification = classificationMap[key] else { continue }
            exercise.muscleGroup = classification.muscleGroup
            exercise.targetMuscles = classification.targetMuscles
            exercise.exerciseDescription = classification.description
            if let instructions = classification.instructions {
                exercise.instructions = instructions
            }
            updatedExerciseCount += 1
        }

        // Backfill WorkoutLog entries
        var backfilledLogCount = 0
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
                backfilledLogCount += 1
            }
        }

        logger.info(
            "csv_import_classification success classified=\(classificationMap.count, privacy: .public) updatedExercises=\(updatedExerciseCount, privacy: .public) backfilledLogs=\(backfilledLogCount, privacy: .public)"
        )
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
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy", "d MMM yyyy, HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
