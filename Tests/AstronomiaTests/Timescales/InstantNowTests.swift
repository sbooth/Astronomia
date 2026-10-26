//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Testing
@testable import Astronomia

@Suite struct InstantNowTests {
	/// POSIX time at 2017-01-01T00:00:00 UTC, the midnight after the leap second of 2016.
	static let newYear2017: Int64 = 1_483_228_800

	@Test func epoch() throws {
		let epoch = try Instant<UTC>(unixSeconds: 0, nanoseconds: 0)
		#expect(epoch.julianDate == JulianDate(uncheckedJulianDayNumber: 2_440_588, fractionFromNoon: -0.5))
		#expect(try JulianDate(year: 1970, month: 1, day: 1) == epoch.julianDate)
	}

	@Test func ordinaryDay() throws {
		// 2017-01-01T12:00:00.5 is half a day and half a second past midnight.
		let instant = try Instant<UTC>(unixSeconds: Self.newYear2017 + 43_200, nanoseconds: 500_000_000)
		#expect(instant.julianDate.julianDayNumber == 2_457_755)
		#expect(abs(try clockReading(instant.julianDate) - 43_200.5) < 1e-6)
	}

	@Test func dayEndingInALeapSecond() throws {
		// On 2016-12-31, 86,401 clock seconds long, a reading's fraction is of 86,401 seconds,
		// not 86,400, and 23:59:59 is a second before the end of the day, not two.
		let day = try UTCDay(julianDayNumber: 2_457_754)
		#expect(day.clockSeconds == 86_401)
		for seconds in [0, 43_200, 86_399] as [Int64] {
			let instant = try Instant<UTC>(unixSeconds: Self.newYear2017 - 86_400 + seconds, nanoseconds: 0)
			#expect(instant.julianDate == (try day.julianDate(secondsSinceMidnight: Double(seconds))))
			#expect(abs(try clockReading(instant.julianDate) - Double(seconds)) < 1e-6)
		}
		let noon = try Instant<UTC>(unixSeconds: Self.newYear2017 - 43_200, nanoseconds: 0)
		#expect(abs(noon.julianDate.fractionSinceMidnight - 43_200 / 86_401) < 1e-15)
		// The next midnight starts the next day.
		let midnight = try Instant<UTC>(unixSeconds: Self.newYear2017, nanoseconds: 0)
		#expect(midnight.julianDate == JulianDate(uncheckedJulianDayNumber: 2_457_755, fractionFromNoon: -0.5))
	}

	@Test func beforeTheEpoch() throws {
		// A second before the epoch is the last second of 1969-12-31, not of 1970-01-01.
		let instant = try Instant<UTC>(unixSeconds: -1, nanoseconds: 250_000_000)
		#expect(instant.julianDate.julianDayNumber == 2_440_587)
		#expect(abs(try clockReading(instant.julianDate) - 86_399.25) < 1e-6)
		// UTC began on 1961-01-01, 3,287 days before the epoch.
		#expect(try Instant<UTC>(unixSeconds: -3_287 * 86_400, nanoseconds: 0).julianDate.julianDayNumber == 2_437_301)
		#expect(throws: TimescaleConversionError.unsupported) {
			try Instant<UTC>(unixSeconds: -3_287 * 86_400 - 1, nanoseconds: 0)
		}
	}

	@Test func now() throws {
		let instant = try Instant<UTC>.now
		// After this test was written, and well before the end of the built-in data
		#expect(instant.julianDate > (try JulianDate(year: 2026, month: 10, day: 24)))
		#expect(instant.julianDate < (try JulianDate(year: 2100, month: 1, day: 1)))
		#expect(throws: Never.self) { try instant.converted(to: TT.self) }
#if canImport(FoundationEssentials) || canImport(Foundation)
		// Within a second or two of Foundation's clock, read just after
		let date = try Instant<UTC>(Date())
		let seconds = (date.julianDate.julianDate - instant.julianDate.julianDate) * 86_400
		#expect(seconds > -1e-3 && seconds < 2, "\(seconds)")
#endif
	}
}
