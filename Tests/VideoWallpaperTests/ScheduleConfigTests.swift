// Tests/VideoWallpaperTests/ScheduleConfigTests.swift
import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct ScheduleConfigTests {

    private let config = ScheduleConfig.default  // morning=6, afternoon=12, night=18

    // MARK: - currentSlot(at:)

    @Test func hour_before_morning_returns_night() {
        #expect(config.currentSlot(at: 0) == .night)
        #expect(config.currentSlot(at: 5) == .night)
    }

    @Test func morning_boundary_returns_morning() {
        #expect(config.currentSlot(at: 6) == .morning)
    }

    @Test func hour_in_morning_returns_morning() {
        #expect(config.currentSlot(at: 11) == .morning)
    }

    @Test func afternoon_boundary_returns_afternoon() {
        #expect(config.currentSlot(at: 12) == .afternoon)
    }

    @Test func hour_in_afternoon_returns_afternoon() {
        #expect(config.currentSlot(at: 17) == .afternoon)
    }

    @Test func night_boundary_returns_night() {
        #expect(config.currentSlot(at: 18) == .night)
    }

    @Test func hour_at_end_of_night_returns_night() {
        #expect(config.currentSlot(at: 23) == .night)
    }

    // MARK: - isValid

    @Test func valid_config_returns_true() {
        #expect(config.isValid)
    }

    @Test func invalid_config_falls_back_to_default() {
        let invalid = ScheduleConfig(morningStart: 25, afternoonStart: 12, nightStart: 18)
        #expect(!invalid.isValid)
        #expect(invalid.currentSlot(at: 7) == .morning)
    }

    @Test func reversed_order_is_invalid() {
        let reversed = ScheduleConfig(morningStart: 18, afternoonStart: 12, nightStart: 6)
        #expect(!reversed.isValid)
        #expect(reversed.currentSlot(at: 7) == .morning)
    }

    @Test func negative_hour_is_invalid() {
        let negative = ScheduleConfig(morningStart: -1, afternoonStart: 12, nightStart: 18)
        #expect(!negative.isValid)
    }

    @Test func equal_boundaries_are_invalid() {
        let equal = ScheduleConfig(morningStart: 6, afternoonStart: 6, nightStart: 18)
        #expect(!equal.isValid)
    }

    // MARK: - Codable

    @Test func codable_roundtrip() throws {
        let original = ScheduleConfig(morningStart: 7, afternoonStart: 13, nightStart: 21)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)
        #expect(decoded == original)
    }
}
