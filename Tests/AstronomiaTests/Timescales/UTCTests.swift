//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// A leap second, identified by the first day of the month that starts after it.
struct LeapSecond: Sendable, CustomTestStringConvertible {
	let year: Int
	let month: Int
	/// TAI - UTC from the start of that month, in seconds.
	let taiMinusUTC: Double

	var testDescription: String { "\(year)-\(month) (TAI - UTC = \(Int(taiMinusUTC)) s)" }
}

/// Every positive leap second, from IERS Bulletin C.
let leapSeconds: [LeapSecond] = [
	.init(year: 1972, month: 7, taiMinusUTC: 11),
	.init(year: 1973, month: 1, taiMinusUTC: 12),
	.init(year: 1974, month: 1, taiMinusUTC: 13),
	.init(year: 1975, month: 1, taiMinusUTC: 14),
	.init(year: 1976, month: 1, taiMinusUTC: 15),
	.init(year: 1977, month: 1, taiMinusUTC: 16),
	.init(year: 1978, month: 1, taiMinusUTC: 17),
	.init(year: 1979, month: 1, taiMinusUTC: 18),
	.init(year: 1980, month: 1, taiMinusUTC: 19),
	.init(year: 1981, month: 7, taiMinusUTC: 20),
	.init(year: 1982, month: 7, taiMinusUTC: 21),
	.init(year: 1983, month: 7, taiMinusUTC: 22),
	.init(year: 1985, month: 7, taiMinusUTC: 23),
	.init(year: 1988, month: 1, taiMinusUTC: 24),
	.init(year: 1990, month: 1, taiMinusUTC: 25),
	.init(year: 1991, month: 1, taiMinusUTC: 26),
	.init(year: 1992, month: 7, taiMinusUTC: 27),
	.init(year: 1993, month: 7, taiMinusUTC: 28),
	.init(year: 1994, month: 7, taiMinusUTC: 29),
	.init(year: 1996, month: 1, taiMinusUTC: 30),
	.init(year: 1997, month: 7, taiMinusUTC: 31),
	.init(year: 1999, month: 1, taiMinusUTC: 32),
	.init(year: 2006, month: 1, taiMinusUTC: 33),
	.init(year: 2009, month: 1, taiMinusUTC: 34),
	.init(year: 2012, month: 7, taiMinusUTC: 35),
	.init(year: 2015, month: 7, taiMinusUTC: 36),
	.init(year: 2017, month: 1, taiMinusUTC: 37),
]

@Suite struct UTCLeapSecondTests {
	@Test(arguments: leapSeconds)
	func midnightAfterLeapSecond(leap: LeapSecond) throws {
		let day = try civilDay(leap.year, leap.month, 1)
		let tai = try Instant<UTC>(utcDate(day)).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - leap.taiMinusUTC) <= timescaleTolerance)
	}

	@Test(arguments: leapSeconds)
	func lastSecondBeforeLeapSecond(leap: LeapSecond) throws {
		// 23:59:59 UTC is TAI - UTC - 1 s after the following midnight in TAI.
		let day = try civilDay(leap.year, leap.month, 1)
		let tai = try Instant<UTC>(utcDate(day - 1, seconds: 86_399)).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - (leap.taiMinusUTC - 2)) <= timescaleTolerance)
	}

	@Test(arguments: leapSeconds)
	func duringLeapSecond(leap: LeapSecond) throws {
		// 23:59:60.5 UTC is TAI - UTC - 0.5 s after the following midnight in TAI.
		let day = try civilDay(leap.year, leap.month, 1)
		let utc = try utcDate(day - 1, seconds: 86_400.5)
		let tai = try Instant<UTC>(utc).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - (leap.taiMinusUTC - 0.5)) <= timescaleTolerance)

		let back = try tai.converted(to: UTC.self)
		#expect(back.julianDate.julianDayNumber == day - 1, "the leap second belongs to the day it ends")
		#expect(try abs(clockReading(back.julianDate) - 86_400.5) <= timescaleTolerance)
	}

	@Test func utcToTT() throws {
		// 2017-01-01T00:00:00 UTC is 00:01:09.184 TT.
		let day = try civilDay(2017, 1, 1)
		let tt = try Instant<UTC>(utcDate(day)).converted(to: TT.self)
		#expect(try tt.julianDate.isApproximatelyEqual(to: uniformDate(day, seconds: 69.184), toleranceSeconds: timescaleTolerance))
		let utc = try tt.converted(to: UTC.self)
		#expect(try utc.julianDate.isApproximatelyEqual(to: utcDate(day), toleranceSeconds: timescaleTolerance))
	}

	@Test func sweepAcross2016LeapSecond() throws {
		// TAI from 2017-01-01T00:00:30 to 00:00:40 in quarter seconds, which is UTC from
		// 2016-12-31T23:59:54 to 2017-01-01T00:00:03 including 23:59:60.
		let day = try civilDay(2017, 1, 1)
		var previous: Instant<UTC>?
		for step in 0 ... 40 {
			let taiSeconds = 30 + Double(step) * 0.25
			let tai = try Instant<TAI>(uniformDate(day, seconds: taiSeconds))
			let utc = try tai.converted(to: UTC.self)

			let expectedDay = taiSeconds < 37 ? day - 1 : day
			let expectedReading = taiSeconds < 37 ? 86_364 + taiSeconds : taiSeconds - 37
			#expect(utc.julianDate.julianDayNumber == expectedDay, "TAI 00:00:\(taiSeconds)")
			#expect(try abs(clockReading(utc.julianDate) - expectedReading) <= timescaleTolerance, "TAI 00:00:\(taiSeconds)")

			if let previous {
				#expect(previous < utc, "UTC must increase at TAI 00:00:\(taiSeconds)")
			}
			previous = utc

			let back = try utc.converted(to: TAI.self)
			#expect(back.julianDate.isApproximatelyEqual(to: tai.julianDate, toleranceSeconds: timescaleTolerance))
		}
	}

	@Test(arguments: utcSampleDates)
	func roundTrip(date: JulianDate) throws {
		try expectRoundTrip(UTC.self, TT.self, date: date)
		try expectRoundTrip(UTC.self, TAI.self, date: date)
		try expectRoundTrip(UTC.self, GPS.self, date: date)
		try expectRoundTrip(TT.self, UTC.self, date: date)
	}
}

/// A pre-1972 day that ends in a step in TAI - UTC.
struct StepDay: Sendable, CustomTestStringConvertible {
	let year: Int
	let month: Int
	let day: Int
	/// The number of seconds the UTC clock counts over the day.
	let clockSeconds: Double

	var testDescription: String { "\(year)-\(month)-\(day)" }
}

/// Pre-1972 days ending in a step, from tai-utc.dat.
let stepDays: [StepDay] = [
	.init(year: 1961, month: 7, day: 31, clockSeconds: 86_399.95),
	.init(year: 1963, month: 10, day: 31, clockSeconds: 86_400.1),
	.init(year: 1964, month: 3, day: 31, clockSeconds: 86_400.1),
	.init(year: 1964, month: 8, day: 31, clockSeconds: 86_400.1),
	.init(year: 1964, month: 12, day: 31, clockSeconds: 86_400.1),
	.init(year: 1965, month: 2, day: 28, clockSeconds: 86_400.1),
	.init(year: 1965, month: 6, day: 30, clockSeconds: 86_400.1),
	.init(year: 1965, month: 8, day: 31, clockSeconds: 86_400.1),
	.init(year: 1968, month: 1, day: 31, clockSeconds: 86_399.9),
	.init(year: 1971, month: 12, day: 31, clockSeconds: 86_400.107_758),
]

@Suite struct UTCBefore1972Tests {
	@Test(arguments: [0.0, 21_600, 43_200, 86_399.5])
	func drift(clockSeconds: Double) throws {
		// 1965-06-15 (MJD 38926) uses the 1965-03-01 entry:
		// TAI - UTC = 3.6401300 s + (MJD - 38761) × 0.001296 s.
		let day = try civilDay(1965, 6, 15)
		let mjd = 38_926 + clockSeconds / 86_400
		let expected = clockSeconds + 3.640_13 + (mjd - 38_761) * 0.001_296

		let utc = try utcDate(day, seconds: clockSeconds)
		let tai = try Instant<UTC>(utc).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - expected) <= driftTolerance)

		let back = try tai.converted(to: UTC.self)
		#expect(back.julianDate.julianDayNumber == day)
		#expect(try abs(clockReading(back.julianDate) - clockSeconds) <= driftTolerance)
	}

	@Test func stepInto1972() throws {
		// 1971-12-31 ends with a step of 0.107758 s, so 23:59:60.1 is a valid reading.
		let day = try civilDay(1971, 12, 31)
		let reading = 86_400.1
		// TAI - UTC = 4.2131700 s + (MJD - 39126) × 0.002592 s at MJD 41316 + reading / 86400.
		let expected = reading + 4.213_17 + (41_316 + reading / 86_400 - 39_126) * 0.002_592
		let tai = try Instant<UTC>(utcDate(day, seconds: reading)).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - expected) <= driftTolerance)

		// 1972-01-01T00:00:00 UTC is exactly 10 s behind TAI.
		let first1972 = try Instant<UTC>(utcDate(day + 1)).converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day + 1), to: first1972.julianDate) - 10) <= timescaleTolerance)
	}

	@Test(arguments: stepDays)
	func stepDayRoundTrip(stepDay: StepDay) throws {
		let day = try civilDay(stepDay.year, stepDay.month, stepDay.day)
		for reading in [0, 43_200, stepDay.clockSeconds - 0.05, stepDay.clockSeconds - 1e-6] {
			let utc = try utcDate(day, seconds: reading)
			let back = try Instant<UTC>(utc).converted(to: TAI.self).converted(to: UTC.self)
			#expect(back.julianDate.julianDayNumber == day, "reading \(reading)")
			#expect(try abs(clockReading(back.julianDate) - reading) <= driftTolerance, "reading \(reading)")
		}
	}

	@Test func sweepAcrossNegativeStep() throws {
		// 1961-07-31 ends 0.05 s early: the clock jumps from 23:59:59.95 to 00:00:00.
		let day = try civilDay(1961, 8, 1)
		let midnight = try Instant<UTC>(utcDate(day)).converted(to: TAI.self)
		var previous: Instant<UTC>?
		for step in -20 ... 20 {
			let tai = try Instant<TAI>(midnight.julianDate.adding(seconds: Double(step) * 0.1))
			let utc = try tai.converted(to: UTC.self)
			#expect(utc.julianDate.julianDayNumber == (step < 0 ? day - 1 : day), "step \(step)")
			if let previous {
				#expect(previous < utc, "UTC must increase at step \(step)")
			}
			previous = utc
			let back = try utc.converted(to: TAI.self)
			#expect(back.julianDate.isApproximatelyEqual(to: tai.julianDate, toleranceSeconds: driftTolerance), "step \(step)")
		}
	}

	@Test func before1961IsUnsupported() throws {
		let lastUnsupported = try civilDay(1960, 12, 31)
		#expect(throws: TimescaleConversionError.unsupported) {
			try UTCDay(julianDayNumber: lastUnsupported)
		}
		let utc = try Instant<UTC>(uniformDate(lastUnsupported, seconds: 43_200))
		#expect(throws: TimescaleConversionError.unsupported) {
			try utc.converted(to: TT.self)
		}

		// 1961-01-01T00:00:01.0 TAI is 1960-12-31T23:59:59.58 UTC.
		let first = try civilDay(1961, 1, 1)
		let earlyTAI = try Instant<TAI>(uniformDate(first, seconds: 1))
		#expect(throws: TimescaleConversionError.unsupported) {
			try earlyTAI.converted(to: UTC.self)
		}

		// 1961-01-01T00:00:01.5 TAI is about 1961-01-01T00:00:00.077182 UTC.
		let firstTAI = try Instant<TAI>(uniformDate(first, seconds: 1.5))
		let firstUTC = try firstTAI.converted(to: UTC.self)
		#expect(firstUTC.julianDate.julianDayNumber == first)
		#expect(try abs(clockReading(firstUTC.julianDate) - 0.077_182) <= driftTolerance)
	}
}

@Suite struct UTCExtrapolationTests {
	/// 2027-06-30, the first day whose length Bulletin C has not determined.
	let horizon: JulianDayNumber = 2_461_587

	@Test func builtInHorizon() throws {
		#expect(try LeapSecondTable.builtIn.horizon == civilDay(2027, 6, 30))
	}

	@Test func offsetSource() throws {
		#expect(try UTCDay(julianDayNumber: horizon - 1).offsetSource == .bulletin)
		#expect(try UTCDay(julianDayNumber: horizon).offsetSource == .extrapolation)
	}

	@Test func strictUTCToTT() throws {
		let lastKnown = try Instant<UTC>(utcDate(horizon - 1, seconds: 86_399))
		#expect(throws: Never.self) {
			try lastKnown.converted(to: TT.self, sourceContext: strictContext)
		}

		let firstUnknown = try Instant<UTC>(utcDate(horizon))
		#expect(throws: TimescaleConversionError.leapSecondTableExpired) {
			try firstUnknown.converted(to: TT.self, sourceContext: strictContext)
		}

		// The default policy assumes no further leap seconds.
		let tai = try firstUnknown.converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(horizon), to: tai.julianDate) - 37) <= timescaleTolerance)
	}

	@Test func strictTTToUTC() throws {
		// 00:00:36.5 TAI on the horizon day is 23:59:59.5 UTC the day before.
		let beforeHorizon = try Instant<TAI>(uniformDate(horizon, seconds: 36.5))
		let utc = try beforeHorizon.converted(to: UTC.self, targetContext: strictContext)
		#expect(utc.julianDate.julianDayNumber == horizon - 1)

		// 00:00:37.5 TAI is 00:00:00.5 UTC on the horizon day.
		let afterHorizon = try Instant<TAI>(uniformDate(horizon, seconds: 37.5))
		#expect(throws: TimescaleConversionError.leapSecondTableExpired) {
			try afterHorizon.converted(to: UTC.self, targetContext: strictContext)
		}
		let extrapolated = try afterHorizon.converted(to: UTC.self)
		#expect(extrapolated.julianDate.julianDayNumber == horizon)
		#expect(try abs(clockReading(extrapolated.julianDate) - 0.5) <= timescaleTolerance)
	}

	@Test func conversionsWithoutContextUseDefault() throws {
		// Timescales with a context convert with their default context when none is given.
		let utc = try utcDate(civilDay(2026, 10, 17), seconds: 43_200)
		let tt = try UTC.toTT(utc)
		#expect(try tt == UTC.toTT(utc, context: UTC.defaultContext))
		#expect(try UTC.fromTT(tt) == UTC.fromTT(tt, context: UTC.defaultContext))
		#expect(try UT1.fromTT(tt) == UT1.fromTT(tt, context: UT1.defaultContext))
		#expect(try TDB.fromTT(tt) == TDB.fromTT(tt, context: TDB.defaultContext))
	}

	@Test func farFuture() throws {
		let day = try civilDay(2200, 1, 1)
		let utc = try Instant<UTC>(utcDate(day, seconds: 43_200))
		let tai = try utc.converted(to: TAI.self)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - 43_237) <= timescaleTolerance)
		#expect(throws: TimescaleConversionError.leapSecondTableExpired) {
			try utc.converted(to: TAI.self, sourceContext: strictContext)
		}
	}

	@Test func lastRepresentableDay() throws {
		// 23:59:30 UTC on the day before the last representable day is 00:00:39.184 TT on the
		// last, with TAI - UTC held at 37 s. A UTC day needs the next day's offset, so the last
		// day itself cannot be a UTC day.
		let utc = try utcDate(.max - 1, seconds: 86_370)
		let tt = try UTC.toTT(utc, context: UTC.defaultContext)
		#expect(tt.julianDayNumber == .max)
		#expect(try abs(seconds(from: uniformDate(.max), to: tt) - 39.184) <= timescaleTolerance)
		let back = try UTC.fromTT(tt, context: UTC.defaultContext)
		#expect(back.julianDayNumber == .max - 1)
		#expect(try abs(clockReading(back) - 86_370) <= timescaleTolerance)

		// Past the end of that UTC day, the UTC day would be the last representable day.
		let later = try uniformDate(.max, seconds: 90)
		#expect(throws: TimescaleConversionError.dateOutOfRange) { try UTC.fromTT(later, context: UTC.defaultContext) }
	}
}

@Suite struct UTCContextTests {
	/// The built-in table plus a fictitious leap second at the end of 2027-06-30.
	func tableWithExtraLeapSecond() throws -> LeapSecondTable {
		var leapSeconds = LeapSecondTable.builtIn.leapSeconds
		leapSeconds.append(try .init(effective: civilDay(2027, 7, 1), taiMinusUTC: 38))
		return try #require(LeapSecondTable(leapSeconds: leapSeconds, horizon: civilDay(2028, 1, 1)))
	}

	@Test func utcToTTUsesContextTable() throws {
		let table = try tableWithExtraLeapSecond()
		let context = UTC.Context(leapSecondTable: table, extrapolationPolicy: .strict)
		let day = try civilDay(2027, 7, 1)
		let utc = try Instant<UTC>(utcDate(day, table: table))
		let tai = try utc.converted(to: TAI.self, sourceContext: context)
		#expect(try abs(seconds(from: uniformDate(day), to: tai.julianDate) - 38) <= timescaleTolerance)
	}

	@Test func ttToUTCUsesContextTable() throws {
		let table = try tableWithExtraLeapSecond()
		let context = UTC.Context(leapSecondTable: table, extrapolationPolicy: .strict)
		let day = try civilDay(2027, 7, 1)
		// 00:00:37.5 TAI is 23:59:60.5 UTC on 2027-06-30 with the extra leap second.
		let tai = try Instant<TAI>(uniformDate(day, seconds: 37.5))
		let utc = try tai.converted(to: UTC.self, targetContext: context)
		#expect(utc.julianDate.julianDayNumber == day - 1)
		#expect(try abs(clockReading(utc.julianDate, table: table) - 86_400.5) <= timescaleTolerance)
	}
}
