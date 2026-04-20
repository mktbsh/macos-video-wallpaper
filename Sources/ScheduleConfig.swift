// Sources/ScheduleConfig.swift
import Foundation

struct ScheduleConfig: Codable, Equatable {
    var morningStart: Int    // 0-23
    var afternoonStart: Int
    var nightStart: Int

    static let `default` = ScheduleConfig(morningStart: 6, afternoonStart: 12, nightStart: 18)
    static let storageKey = "schedule.config"

    var isValid: Bool {
        (0..<24).contains(morningStart)
            && (0..<24).contains(afternoonStart)
            && (0..<24).contains(nightStart)
            && morningStart < afternoonStart
            && afternoonStart < nightStart
    }

    /// 時刻（hour: 0-23）からスロットを返す。
    /// morning: [morningStart, afternoonStart)
    /// afternoon: [afternoonStart, nightStart)
    /// night: [nightStart, 24) ∪ [0, morningStart)
    func currentSlot(at hour: Int) -> TimeSlot {
        let config = isValid ? self : Self.default
        if hour >= config.nightStart || hour < config.morningStart {
            return .night
        } else if hour >= config.afternoonStart {
            return .afternoon
        } else {
            return .morning
        }
    }
}
