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

    @Transient private var _instructionsCache: [String]?
    @Transient private var _targetMusclesCache: [TargetMuscle]?

    var instructions: [String] {
        get {
            if let cached = _instructionsCache { return cached }
            guard let data = instructionsData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([String].self, from: data)
                _instructionsCache = decoded
                return decoded
            } catch {
                logger.error("Failed to decode instructions: \(error)")
                return []
            }
        }
        set {
            do {
                instructionsData = try JSONEncoder().encode(newValue)
                _instructionsCache = newValue
            } catch {
                logger.error("Failed to encode instructions: \(error)")
            }
        }
    }

    var targetMuscles: [TargetMuscle] {
        get {
            if let cached = _targetMusclesCache { return cached }
            guard let data = targetMusclesData else { return [] }
            let decoded = (try? JSONDecoder().decode([TargetMuscle].self, from: data)) ?? []
            _targetMusclesCache = decoded
            return decoded
        }
        set {
            targetMusclesData = try? JSONEncoder().encode(newValue)
            _targetMusclesCache = newValue
        }
    }

    init(name: String, muscleGroup: String, exerciseDescription: String? = nil, instructions: [String] = [], targetMuscles: [TargetMuscle] = []) {
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
