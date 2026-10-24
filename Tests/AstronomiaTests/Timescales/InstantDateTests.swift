//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(FoundationEssentials) || canImport(Foundation)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Testing
@testable import Astronomia

@Suite struct InstantDateTests {
	/// Seconds since the `Date` reference epoch at 2017-01-01T00:00:00 UTC, the midnight after
	/// the leap second of 2016.
	static let newYear2017: TimeInterval = 504_921_600

	@Test func knownInstants() throws {
		// The reference epoch, 2001-01-01T00:00:00 UTC, and the Unix epoch
		let reference = try Instant<UTC>(Date(timeIntervalSinceReferenceDate: 0))
		#expect(reference.julianDate == JulianDate(uncheckedJulianDayNumber: 2_451_911, fractionFromNoon: -0.5))
		#expect(try reference.date == Date(timeIntervalSinceReferenceDate: 0))
		let unix = try Instant<UTC>(Date(timeIntervalSince1970: 0))
		#expect(unix.julianDate == JulianDate(uncheckedJulianDayNumber: 2_440_588, fractionFromNoon: -0.5))
		// Noon of an ordinary day
		let noon = try Instant<UTC>(Date(timeIntervalSinceReferenceDate: Self.newYear2017 + 43_200))
		#expect(noon.julianDate == JulianDate(uncheckedJulianDayNumber: 2_457_755, fractionFromNoon: 0))
	}

	@Test func dayEndingInALeapSecond() throws {
		// On 2016-12-31, 86,401 clock seconds long, a reading's fraction is of 86,401 seconds.
		let day = try UTCDay(julianDayNumber: 2_457_754)
		for seconds in [0.0, 43_200, 86_399.5] {
			let instant = try Instant<UTC>(Date(timeIntervalSinceReferenceDate: Self.newYear2017 - 86_400 + seconds))
			#expect(instant.julianDate == (try day.julianDate(secondsSinceMidnight: seconds)))
			#expect(abs(try instant.date.timeIntervalSinceReferenceDate - (Self.newYear2017 - 86_400 + seconds)) < 1e-6)
		}
		// The leap second itself, 23:59:60.25, repeats 23:59:59.25 as a `Date`.
		let leapSecond = Instant<UTC>(try day.julianDate(secondsSinceMidnight: 86_400.25))
		#expect(abs(try leapSecond.date.timeIntervalSinceReferenceDate - (Self.newYear2017 - 0.75)) < 1e-6)
		// The next midnight starts the next day.
		let midnight = try Instant<UTC>(Date(timeIntervalSinceReferenceDate: Self.newYear2017))
		#expect(midnight.julianDate == JulianDate(uncheckedJulianDayNumber: 2_457_755, fractionFromNoon: -0.5))
	}

	@Test func roundTrip() throws {
		// From 1961, before the reference epoch, through the present to the future
		for t in [-1_262_304_000, -978_307_200, -1.5, 0, 0.25, 43_200, 86_399.999, 8e8, 3e9] {
			let date = Date(timeIntervalSinceReferenceDate: t)
			#expect(abs(try Instant<UTC>(date).date.timeIntervalSinceReferenceDate - t) <= 1e-6, "\(t)")
		}
	}

	@Test func convertsToOtherTimescales() throws {
		// TT is 69.184 s ahead of UTC in 2017.
		let utc = try Instant<UTC>(Date(timeIntervalSinceReferenceDate: Self.newYear2017))
		let tt = try utc.converted(to: TT.self)
		#expect(abs((tt.julianDate.daysSinceJ2000 - utc.julianDate.daysSinceJ2000) * secondsPerDay - 69.184) < 1e-6)
	}

	@Test func errors() {
		#expect(throws: TimescaleConversionError.nonFiniteValue) { try Instant<UTC>(Date(timeIntervalSinceReferenceDate: .nan)) }
		#expect(throws: TimescaleConversionError.nonFiniteValue) { try Instant<UTC>(Date(timeIntervalSinceReferenceDate: .infinity)) }
		#expect(throws: TimescaleConversionError.dateOutOfRange) { try Instant<UTC>(Date(timeIntervalSinceReferenceDate: 1e300)) }
		// Before UTC began
		#expect(throws: TimescaleConversionError.unsupported) { try Instant<UTC>(Date(timeIntervalSince1970: -315_619_200)) }
		#expect(throws: TimescaleConversionError.unsupported) { try Instant<UTC>(JulianDate.j2000.adding(days: -40 * 365.25)).date }
	}
}

#endif
