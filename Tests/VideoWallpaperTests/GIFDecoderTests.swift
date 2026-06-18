import Testing
@testable import VideoWallpaper

struct GIFDecoderTests {
    @Test func keyTimesAreCumulativeStartTimesNormalized() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.1, 0.1, 0.2])
        #expect(result.duration == 0.4)
        let values = result.keyTimes.map { $0.doubleValue }
        #expect(values.count == 3)
        #expect(abs(values[0] - 0.0) < 1e-9)
        #expect(abs(values[1] - 0.25) < 1e-9)
        #expect(abs(values[2] - 0.5) < 1e-9)
    }

    @Test func zeroOrTinyDelayIsClampedToMinimum() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.0, 0.0])
        #expect(abs(result.duration - 0.2) < 1e-9)
    }

    @Test func singleFrameProducesZeroKeyTimeAndPositiveDuration() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.1])
        #expect(result.keyTimes.map { $0.doubleValue } == [0.0])
        #expect(abs(result.duration - 0.1) < 1e-9)
    }

    @Test func emptyDelaysProducesZeroDuration() {
        let result = GIFDecoder.makeKeyTimes(delays: [])
        #expect(result.keyTimes.isEmpty)
        #expect(result.duration == 0)
    }
}
