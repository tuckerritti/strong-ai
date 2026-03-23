import Foundation
import HealthKit
import os

private let logger = Logger(subsystem: "com.light-weight", category: "HealthKit")

struct HealthContext: Sendable {
    var sleepHours: Double?
    var restingHeartRate: Double?
    var hrv: Double?
    var activeCaloriesToday: Double?

    var promptFragment: String {
        var lines: [String] = []
        if let sleep = sleepHours { lines.append("Sleep last night: \(String(format: "%.1f", sleep)) hours") }
        if let rhr = restingHeartRate { lines.append("Resting heart rate: \(Int(rhr)) bpm") }
        if let hrv { lines.append("HRV: \(Int(hrv)) ms") }
        if let cal = activeCaloriesToday { lines.append("Active calories today: \(Int(cal)) kcal") }
        return lines.isEmpty ? "" : "Health data:\n" + lines.joined(separator: "\n")
    }
}

final class HealthKitService: Sendable {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchRecentHealthData() async -> HealthContext {
        var sleepHours: Double?
        var rhr: Double?
        var hrv: Double?
        var cal: Double?

        do { sleepHours = try await fetchSleepHours() }
        catch { logger.error("Failed to fetch sleep data: \(error)") }

        do { rhr = try await fetchLatestQuantity(.restingHeartRate, unit: HKUnit(from: "count/min")) }
        catch { logger.error("Failed to fetch resting heart rate: \(error)") }

        do { hrv = try await fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) }
        catch { logger.error("Failed to fetch HRV: \(error)") }

        do { cal = try await fetchTodaySum(.activeEnergyBurned, unit: .kilocalorie()) }
        catch { logger.error("Failed to fetch active calories: \(error)") }

        return HealthContext(
            sleepHours: sleepHours,
            restingHeartRate: rhr,
            hrv: hrv,
            activeCaloriesToday: cal
        )
    }

    // MARK: - Private

    private func fetchSleepHours() async throws -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let now = Date()
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) else {
            logger.warning("Could not compute yesterday's date")
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)

        let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: samples as? [HKCategorySample] ?? []) }
            }
            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]

        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return totalSeconds > 0 ? totalSeconds / 3600.0 : nil
    }

    private func fetchLatestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        let type = HKQuantityType(identifier)
        let now = Date()
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) else {
            logger.warning("Could not compute week-ago date")
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let sample = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKQuantitySample?, Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: samples?.first as? HKQuantitySample) }
            }
            store.execute(query)
        }

        return sample?.quantity.doubleValue(for: unit)
    }

    private func fetchTodaySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        let type = HKQuantityType(identifier)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }

        return result
    }
}
