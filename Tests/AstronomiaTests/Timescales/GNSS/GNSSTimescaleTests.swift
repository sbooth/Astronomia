//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Returns the Julian day number of a Gregorian calendar date.
private func jdn(_ year: Int, _ month: Int, _ day: Int) throws -> JulianDayNumber {
	try GregorianCalendar.julianDayNumber(year: year, month: month, day: day)
}

/// Returns the Julian Date for seconds since midnight on a 86,400 s day.
private func date(_ year: Int, _ month: Int, _ day: Int, seconds: Double = 0) throws -> JulianDate {
	JulianDate(uncheckedJulianDayNumber: try jdn(year, month, day), fractionFromNoon: seconds / secondsPerDay - 0.5)
}

/// Returns the UTC Julian Date for a UTC clock reading.
private func utc(_ year: Int, _ month: Int, _ day: Int, seconds: Double = 0) throws -> JulianDate {
	try UTCDay(julianDayNumber: jdn(year, month, day)).julianDate(secondsSinceMidnight: seconds)
}

/// Returns `b - a` in seconds, treating both as plain Julian Dates.
private func secondsBetween(_ a: JulianDate, _ b: JulianDate) throws -> Double {
	try a.interval(to: b).inSeconds
}

/// Returns the reading of `Scale` minus the reading of TAI at the same instant, in seconds.
private func offsetFromTAI<Scale: Timescale>(_ scale: Scale.Type, at tai: JulianDate) throws -> Double where Scale.Context == Void {
	let converted = try Instant<TAI>(tai).converted(to: scale)
	return try secondsBetween(tai, converted.julianDate)
}

/// Returns the round-trip error through `Scale`, in seconds.
private func roundTripError<Scale: Timescale>(_ scale: Scale.Type, _ julianDate: JulianDate, context: Scale.Context = Scale.defaultContext) throws -> Double {
	let tt = try Scale.toTT(julianDate, context: context)
	let back = try Scale.fromTT(tt, context: context)
	return try abs(secondsBetween(julianDate, back))
}

/// A timescale with the most negative offset an `Int` can hold, which cannot be negated.
private enum MinimumOffsetTimescale: FixedTAIOffsetTimescale {
	static var abbreviation: String { "MIN" }
	static var offsetFromTAI: Int { .min }
}

@Suite struct FixedTAIOffsetTimescaleTests {
	@Test func minimumOffset() throws {
		// TAI is 2^63 s after this timescale's reading, about 10^14 days, which is representable.
		let tt = try MinimumOffsetTimescale.toTT(.J2000)
		let expected = try JulianDate.J2000.adding(seconds: Int.max).adding(seconds: 1).adding(seconds: TT.offsetFromTAI)
		#expect(tt.isApproximatelyEqual(to: expected, toleranceSeconds: 1e-6))
		#expect(try MinimumOffsetTimescale.fromTT(tt).isApproximatelyEqual(to: .J2000, toleranceSeconds: 1e-6))
	}

	@Test func offsets() throws {
		let tai = try date(2026, 10, 15, seconds: 43_200)
		#expect(try abs(offsetFromTAI(GPS.self, at: tai) + 19) <= 1e-9)
		#expect(try abs(offsetFromTAI(Galileo.self, at: tai) + 19) <= 1e-9)
		#expect(try abs(offsetFromTAI(QZSS.self, at: tai) + 19) <= 1e-9)
		#expect(try abs(offsetFromTAI(NavIC.self, at: tai) + 19) <= 1e-9)
		#expect(try abs(offsetFromTAI(BeiDou.self, at: tai) + 33) <= 1e-9)
	}

	@Test func beiDouIsBehindGPS() throws {
		let gps = Instant<GPS>(try date(2026, 10, 15, seconds: 1_000))
		let bdt = try gps.converted(to: BeiDou.self)
		#expect(try abs(secondsBetween(gps.julianDate, bdt.julianDate) + 14) <= 1e-9)
	}

	@Test func aheadOfUTC() throws {
		// TAI - UTC = 37 s since 2017, so GPS-aligned times are 18 s ahead of UTC and BDT 4 s.
		let now = Instant<UTC>(try utc(2026, 10, 15, seconds: 43_200))
		#expect(try abs(secondsBetween(now.julianDate, now.converted(to: GPS.self).julianDate) - 18) <= 1e-9)
		#expect(try abs(secondsBetween(now.julianDate, now.converted(to: Galileo.self).julianDate) - 18) <= 1e-9)
		#expect(try abs(secondsBetween(now.julianDate, now.converted(to: BeiDou.self).julianDate) - 4) <= 1e-9)
	}

	@Test func epochs() throws {
		// GPS and BDT equal UTC at their epochs
		let gpsEpoch = try Instant<GPS>(GPS.epoch).converted(to: UTC.self)
		#expect(try abs(secondsBetween(utc(1980, 1, 6), gpsEpoch.julianDate)) <= 1e-9)
		let bdtEpoch = try Instant<BeiDou>(BeiDou.epoch).converted(to: UTC.self)
		#expect(try abs(secondsBetween(utc(2006, 1, 1), bdtEpoch.julianDate)) <= 1e-9)

		// GST and IRNWT start 13 s before UTC midnight, at GPS week 1024
		let gstEpoch = try Instant<Galileo>(Galileo.epoch).converted(to: UTC.self)
		#expect(try abs(secondsBetween(utc(1999, 8, 21, seconds: 86_387), gstEpoch.julianDate)) <= 1e-9)
		let gpsWeek1024 = try GPS.epoch.adding(days: 1024 * 7)
		#expect(try abs(secondsBetween(gpsWeek1024, Instant<Galileo>(Galileo.epoch).converted(to: GPS.self).julianDate)) <= 1e-9)
		#expect(NavIC.epoch == Galileo.epoch)
		#expect(QZSS.epoch == GPS.epoch)

		#expect(try date(1980, 1, 6) == GPS.epoch)
		#expect(try date(1999, 8, 22) == Galileo.epoch)
		#expect(try date(2006, 1, 1) == BeiDou.epoch)
	}

	@Test(arguments: [(1980, 1, 6, 0.0), (1999, 8, 21, 86_387), (2016, 12, 31, 86_399.5), (2026, 10, 15, 12_345.678)])
	func roundTrip(year: Int, month: Int, day: Int, seconds: Double) throws {
		let julianDate = try date(year, month, day, seconds: seconds)
		#expect(try roundTripError(GPS.self, julianDate) <= 1e-9)
		#expect(try roundTripError(Galileo.self, julianDate) <= 1e-9)
		#expect(try roundTripError(BeiDou.self, julianDate) <= 1e-9)
		#expect(try roundTripError(QZSS.self, julianDate) <= 1e-9)
		#expect(try roundTripError(NavIC.self, julianDate) <= 1e-9)
	}
}

@Suite struct GLONASSTests {
	/// Returns the GLONASS Julian Date for a GLONASS clock reading.
	static func glonass(_ year: Int, _ month: Int, _ day: Int, seconds: Double = 0) throws -> JulianDate {
		try GLONASS.julianDate(julianDayNumber: jdn(year, month, day), secondsSinceMidnight: seconds)
	}

	/// Returns the GLONASS day number and clock reading for a UTC clock reading.
	static func fromUTC(_ julianDate: JulianDate) throws -> (JulianDayNumber, Double) {
		let glonass = try Instant<UTC>(julianDate).converted(to: GLONASS.self).julianDate
		let seconds = try GLONASS.secondsSinceMidnight(at: glonass)
		return (glonass.julianDayNumber, seconds)
	}

	@Test func threeHoursAheadOfUTC() throws {
		let (noonDay, noonSeconds) = try Self.fromUTC(utc(2026, 10, 14, seconds: 43_200))
		#expect(try jdn(2026, 10, 14) == noonDay)
		#expect(abs(noonSeconds - 54_000) <= 1e-6)

		// 22:30 UTC is 01:30 the next GLONASS day
		let (lateDay, lateSeconds) = try Self.fromUTC(utc(2026, 10, 14, seconds: 81_000))
		#expect(try jdn(2026, 10, 15) == lateDay)
		#expect(abs(lateSeconds - 5_400) <= 1e-6)
	}

	@Test func leapSecondFallsAtThreeAM() throws {
		// 2016-12-31 23:59:60.5 UTC is 2017-01-01 02:59:60.5 GLONASS
		let (day, seconds) = try Self.fromUTC(utc(2016, 12, 31, seconds: 86_400.5))
		#expect(try jdn(2017, 1, 1) == day)
		#expect(abs(seconds - 10_800.5) <= 1e-6)

		// 21:00 UTC starts the GLONASS day; 00:00 UTC is 03:00, counted as 10,801 elapsed seconds
		let (startDay, startSeconds) = try Self.fromUTC(utc(2016, 12, 31, seconds: 75_600))
		#expect(try jdn(2017, 1, 1) == startDay)
		#expect(abs(startSeconds) <= 1e-6)
		let (midnightDay, midnightSeconds) = try Self.fromUTC(utc(2017, 1, 1))
		#expect(try jdn(2017, 1, 1) == midnightDay)
		#expect(abs(midnightSeconds - 10_801) <= 1e-6)

		// The GLONASS day containing the leap second reads up to 86,401 s
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try Self.glonass(2017, 1, 1, seconds: 86_401)
		}
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try Self.glonass(2017, 1, 2, seconds: 86_400)
		}
	}

	@Test(arguments: [0, 10_799.5, 10_800, 10_800.5, 10_801, 50_000, 86_400.5])
	func elapsedSecondsMatchTAI(seconds: Double) throws {
		// Across the leap-second day, GLONASS elapsed seconds equal TAI elapsed seconds
		let start = try Instant<GLONASS>(Self.glonass(2017, 1, 1)).converted(to: TAI.self)
		let later = try Instant<GLONASS>(Self.glonass(2017, 1, 1, seconds: seconds)).converted(to: TAI.self)
		#expect(try abs(secondsBetween(start.julianDate, later.julianDate) - seconds) <= 1e-6)
	}

	@Test(arguments: [
		(2016, 12, 31, 0.0), (2017, 1, 1, 10_799.5), (2017, 1, 1, 10_800.5), (2017, 1, 1, 10_801),
		(2017, 1, 1, 86_400.5), (2017, 1, 2, 0), (2026, 10, 15, 12_345.678), (1972, 1, 1, 5_000),
	])
	func roundTrip(year: Int, month: Int, day: Int, seconds: Double) throws {
		let julianDate = try Self.glonass(year, month, day, seconds: seconds)
		#expect(try roundTripError(GLONASS.self, julianDate) <= 1e-9)
	}

	@Test func errors() throws {
		let pastHorizon = try Self.glonass(2027, 7, 1, seconds: 43_200)
		let reject = UTC.Context(leapSecondTable: .builtIn, extrapolationPolicy: .reject)
		#expect(throws: TimescaleConversionError.leapSecondTableExpired) {
			try GLONASS.toTT(pastHorizon, context: reject)
		}
		_ = try GLONASS.toTT(pastHorizon, context: GLONASS.defaultContext)

		#expect(throws: TimescaleConversionError.unsupported) {
			try GLONASS.toTT(date(1961, 1, 1, seconds: 43_200), context: GLONASS.defaultContext)
		}
		#expect(throws: TimescaleConversionError.nonFiniteValue) {
			try Self.glonass(2026, 10, 15, seconds: .nan)
		}
	}
}
