//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct UTCTAIMinusUTCTests {
	/// Returns the UTC Julian Date for a clock reading on a Gregorian calendar date.
	static func utc(_ year: Int, _ month: Int, _ day: Int, seconds: Double = 0) throws -> JulianDate {
		let j = try GregorianCalendar.julianDayNumber(year: year, month: month, day: day)
		return try UTCDay(julianDayNumber: j).julianDate(secondsSinceMidnight: seconds)
	}

	@Test(arguments: [0.0, 43_200, 86_399.5, 86_400.5])
	func constantThroughLeapSecondDay(seconds: Double) throws {
		// 2016-12-31 ends in a leap second; TAI - UTC is still 36 s during 23:59:60.
		#expect(try UTC.taiMinusUTC(at: Self.utc(2016, 12, 31, seconds: seconds)) == 36)
	}

	@Test func afterLeapSecond() throws {
		#expect(try UTC.taiMinusUTC(at: Self.utc(2017, 1, 1)) == 37)
		#expect(try UTC.taiMinusUTC(at: Self.utc(2026, 10, 14, seconds: 43_200)) == 37)
		#expect(try UTC.taiMinusUTC(at: Self.utc(1972, 1, 1)) == 10)
	}

	@Test func driftBefore1972() throws {
		// 1965-06-15 is MJD 38926: 3.6401300 s + (MJD - 38761) × 0.001296 s.
		#expect(try abs(UTC.taiMinusUTC(at: Self.utc(1965, 6, 15)) - 3.853_97) <= 1e-12)
		#expect(try abs(UTC.taiMinusUTC(at: Self.utc(1965, 6, 15, seconds: 43_200)) - 3.854_618) <= 1e-12)
	}

	@Test func stepDaysExcludeTheStep() throws {
		// 1971-12-31 ends with a 0.107758 s step, which belongs to 1972-01-01.
		#expect(try abs(UTC.taiMinusUTC(at: Self.utc(1971, 12, 31, seconds: 86_400.1)) - 9.892_241_999_767) <= 1e-9)
		// 1961-07-31 ends 0.05 s early.
		#expect(try abs(UTC.taiMinusUTC(at: Self.utc(1961, 7, 31, seconds: 86_399.9)) - 1.697_569_999_250) <= 1e-9)
	}

	@Test(arguments: [
		(1961, 7, 31, 86_399.9), (1965, 6, 15, 43_200), (1971, 12, 31, 86_400.1),
		(2016, 12, 31, 86_400.5), (2017, 1, 1, 0), (2026, 10, 14, 43_200),
	])
	func agreesWithConversion(year: Int, month: Int, day: Int, seconds: Double) throws {
		// TAI = UTC clock reading + (TAI - UTC), with the reading counted from UTC midnight.
		let j = try GregorianCalendar.julianDayNumber(year: year, month: month, day: day)
		let utcDay = try UTCDay(julianDayNumber: j)
		let tai = try utcDay.taiJulianDate(secondsSinceMidnight: seconds)
		let taiMinusClock = try utcDay.start.interval(to: tai).inSeconds - seconds
		let value = try UTC.taiMinusUTC(at: utcDay.julianDate(secondsSinceMidnight: seconds))
		#expect(abs(value - taiMinusClock) <= 1e-8)
	}

	@Test func errors() throws {
		#expect(throws: TimescaleConversionError.unsupported) {
			try UTC.taiMinusUTC(at: JulianDate(julianDayNumber: GregorianCalendar.julianDayNumber(year: 1960, month: 12, day: 31)))
		}

		let pastHorizon = try Self.utc(2027, 6, 30)
		let reject = UTC.Context(leapSecondTable: .builtIn, extrapolationPolicy: .reject)
		#expect(throws: TimescaleConversionError.leapSecondTableExpired) {
			try UTC.taiMinusUTC(at: pastHorizon, context: reject)
		}
		#expect(try UTC.taiMinusUTC(at: pastHorizon) == 37)
	}
}
