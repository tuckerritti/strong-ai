import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.light-weight", category: "Exercise")

@Model
final class Exercise {
    var name: String
    var muscleGroup: String
    var exerciseDescription: String?
    var instructionsData: Data?

    var targetMusclesData: Data?

    var instructions: [String] {
        get {
            guard let data = instructionsData else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                logger.error("Failed to decode instructions: \(error)")
                return []
            }
        }
        set {
            do {
                instructionsData = try JSONEncoder().encode(newValue)
            } catch {
                logger.error("Failed to encode instructions: \(error)")
            }
        }
    }

    var targetMuscles: [String] {
        get {
            guard let data = targetMusclesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            targetMusclesData = try? JSONEncoder().encode(newValue)
        }
    }

    init(name: String, muscleGroup: String, exerciseDescription: String? = nil, instructions: [String] = [], targetMuscles: [String] = []) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.exerciseDescription = exerciseDescription
        if !instructions.isEmpty {
            do {
                self.instructionsData = try JSONEncoder().encode(instructions)
            } catch {
                logger.error("Failed to encode initial instructions: \(error)")
            }
        }
        if !targetMuscles.isEmpty {
            self.targetMusclesData = try? JSONEncoder().encode(targetMuscles)
        }
    }
}
