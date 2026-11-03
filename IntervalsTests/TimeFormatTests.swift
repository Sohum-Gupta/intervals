import Testing
@testable import Intervals

struct TimeFormatTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(TimeFormat.clock(1499) == "24:59")
        #expect(TimeFormat.clock(1500) == "25:00")
        #expect(TimeFormat.clock(0) == "00:00")
        #expect(TimeFormat.clock(5) == "00:05")
    }

    @Test func roundsUpSoTheDisplayNeverShowsZeroEarly() {
        #expect(TimeFormat.clock(1499.2) == "25:00")
        #expect(TimeFormat.clock(0.4) == "00:01")
    }

    @Test func showsHoursWhenNeeded() {
        #expect(TimeFormat.clock(3600) == "1:00:00")
        #expect(TimeFormat.clock(7200 - 1) == "1:59:59")
    }

    @Test func overtimeCountsUpWithAPlus() {
        #expect(TimeFormat.clock(-192) == "+03:12")
        #expect(TimeFormat.clock(-0.5) == "+00:00")
        #expect(TimeFormat.clock(-3661) == "+1:01:01")
    }
}
