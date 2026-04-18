// Sources/TimeSlot.swift
import Foundation

enum TimeSlot: String, CaseIterable, Codable {
    case morning
    case afternoon
    case night

    var label: String {
        switch self {
        case .morning:   return String(localized: "schedule.slot.morning")
        case .afternoon: return String(localized: "schedule.slot.afternoon")
        case .night:     return String(localized: "schedule.slot.night")
        }
    }
}
