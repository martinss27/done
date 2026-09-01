import Foundation
import HealthKit
import Observation

/// Reads today's step count. Garmin writes into Apple Health on its own
/// schedule, so this is refreshed whenever the app comes forward rather than
/// trusted to be live.
@Observable
final class Health {
    var steps = 0
    var workoutMinutes = 0
    var mindfulMinutes = 0

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let workoutType = HKWorkoutType.workoutType()
    private let mindfulType = HKCategoryType(.mindfulSession)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: [stepType, workoutType, mindfulType])
        await refresh()
    }

    func refresh() async {
        guard isAvailable else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let total: Double? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()))
            }
            store.execute(query)
        }
        // Health denies reads silently by returning nothing; keep the last known
        // count rather than dropping to zero and re-locking apps by accident.
        if let total { steps = Int(total) }
        await refreshWorkouts(since: start)
        await refreshMindful(since: start)
    }

    /// Mindful minutes are sessions, not a quantity: sum how long each one ran.
    private func refreshMindful(since start: Date) async {
        guard let samples = await samples(of: mindfulType, since: start) else { return }
        let seconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        mindfulMinutes = Int(seconds / 60)
    }

    private func samples(of type: HKSampleType, since start: Date) async -> [HKSample]? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    /// Total minutes of workouts finished today, across every source.
    private func refreshWorkouts(since start: Date) async {
        guard let samples = await samples(of: workoutType, since: start) else { return }
        let seconds = samples.compactMap { ($0 as? HKWorkout)?.duration }.reduce(0, +)
        workoutMinutes = Int(seconds / 60)
    }
}
