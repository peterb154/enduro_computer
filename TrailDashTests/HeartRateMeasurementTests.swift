import Foundation
import Testing
@testable import TrailDash

struct HeartRateMeasurementTests {
    @Test func parsesEightBitValue() {
        #expect(parseHeartRate(Data([0x00, 72])) == 72)
    }

    @Test func parsesSixteenBitLittleEndianValue() {
        // 0x012C = 300; flags bit 0 set
        #expect(parseHeartRate(Data([0x01, 0x2C, 0x01])) == 300)
    }

    @Test func ignoresTrailingRRIntervals() {
        // flags: 8-bit HR + RR present (bit 4)
        #expect(parseHeartRate(Data([0x10, 155, 0x00, 0x04])) == 155)
    }

    @Test func rejectsTruncatedPackets() {
        #expect(parseHeartRate(Data()) == nil)
        #expect(parseHeartRate(Data([0x00])) == nil)
        #expect(parseHeartRate(Data([0x01, 0x2C])) == nil)
    }
}
