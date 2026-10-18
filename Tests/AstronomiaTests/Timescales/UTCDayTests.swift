//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct UTCDayTests {
	@Test func ordinaryDay() throws {
		let j = try civilDay(2026, 10, 14)
		let day = try UTCDay(julianDayNumber: j)
		#expect(day.julianDayNumber == j)
		#expect(try day.start == uniformDate(j))
		#expect(day.clockSeconds == 86_400)
		#expect(day.duration == 86_400)
		#expect(day.offsetSource == .bulletin)
	}

	@Test func leapSecondDay() throws {
		let day = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		#expect(day.clockSeconds == 86_401)
		#expect(day.duration == 86_401)
		let next = try UTCDay(julianDayNumber: civilDay(2017, 1, 1))
		#expect(next.clockSeconds == 86_400)
	}

	@Test func driftDay() throws {
		// Clock seconds were stretched to absorb the drift of 0.001296 s per day.
		let day = try UTCDay(julianDayNumber: civilDay(1965, 6, 15))
		#expect(day.clockSeconds == 86_400)
		#expect(abs(day.duration - 86_400.001_296) <= 1e-9)
	}

	@Test func rateChangeWithoutStep() throws {
		// The 1964-01-01 entry changes the reference and rate but not TAI - UTC.
		let day = try UTCDay(julianDayNumber: civilDay(1963, 12, 31))
		#expect(day.clockSeconds == 86_400)
	}

	@Test(arguments: stepDays)
	func stepDayLength(stepDay: StepDay) throws {
		let day = try UTCDay(julianDayNumber: civilDay(stepDay.year, stepDay.month, stepDay.day))
		#expect(abs(day.clockSeconds - stepDay.clockSeconds) <= 1e-9)
	}

	@Test func stepInto1972Duration() throws {
		// 1971-12-31 lasts 86,400 s plus 0.002592 s of drift plus the 0.107758 s step.
		let day = try UTCDay(julianDayNumber: civilDay(1971, 12, 31))
		#expect(abs(day.duration - 86_400.110_35) <= 1e-9)
	}

	@Test func validClockReadings() throws {
		let ordinary = try UTCDay(julianDayNumber: civilDay(2026, 10, 14))
		#expect(throws: Never.self) { try ordinary.julianDate(secondsSinceMidnight: 0) }
		#expect(throws: Never.self) { try ordinary.julianDate(secondsSinceMidnight: 86_399.999) }
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) { try ordinary.julianDate(secondsSinceMidnight: 86_400) }
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) { try ordinary.julianDate(secondsSinceMidnight: -0.001) }
		#expect(throws: TimescaleConversionError.nonFiniteValue) { try ordinary.julianDate(secondsSinceMidnight: .nan) }
		#expect(throws: TimescaleConversionError.nonFiniteValue) { try ordinary.julianDate(secondsSinceMidnight: .infinity) }

		let leap = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		#expect(throws: Never.self) { try leap.julianDate(secondsSinceMidnight: 86_400.999) }
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) { try leap.julianDate(secondsSinceMidnight: 86_401) }

		let shortened = try UTCDay(julianDayNumber: civilDay(1961, 7, 31))
		#expect(throws: Never.self) { try shortened.julianDate(secondsSinceMidnight: 86_399.9) }
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) { try shortened.julianDate(secondsSinceMidnight: 86_399.95) }
	}

	@Test(arguments: [0.0, 1, 43_200, 86_399.75, 86_400, 86_400.5, 86_400.999])
	func clockReadingRoundTrip(reading: Double) throws {
		let day = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		let utc = try day.julianDate(secondsSinceMidnight: reading)
		#expect(utc.julianDayNumber == day.julianDayNumber)
		#expect(try abs(day.secondsSinceMidnight(utc) - reading) <= timescaleTolerance)
	}

	@Test func leapSecondFraction() throws {
		// 23:59:60.0 is 86,400 / 86,401 of the way through the day.
		let day = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		let utc = try day.julianDate(secondsSinceMidnight: 86_400)
		#expect(abs(utc.fractionSinceMidnight - 86_400.0 / 86_401) <= 1e-15)
	}

	@Test func secondsSinceMidnightRejectsOtherDays() throws {
		let day = try UTCDay(julianDayNumber: civilDay(2026, 10, 14))
		let otherDay = try uniformDate(day.julianDayNumber + 1)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try day.secondsSinceMidnight(otherDay)
		}
	}

	@Test func textualRepresentation() throws {
		#expect(try UTCDay(julianDayNumber: civilDay(2016, 12, 31)).description == "2016-12-31 UTC, TAI - UTC = 36.0 s, leap second +1.0 s")
		#expect(try UTCDay(julianDayNumber: civilDay(2017, 1, 1)).description == "2017-1-1 UTC, TAI - UTC = 37.0 s")
		// Past the built-in table's horizon
		#expect(try UTCDay(julianDayNumber: civilDay(2200, 1, 1)).description == "2200-1-1 UTC, TAI - UTC = 37.0 s, extrapolated")
		// Before 1972, TAI - UTC drifts through the day, and steps by fractions of a second
		#expect(try UTCDay(julianDayNumber: civilDay(1965, 1, 1)).description == "1965-1-1 UTC, TAI - UTC = 3.54013 s, drift 0.001296 s")
		#expect(try UTCDay(julianDayNumber: civilDay(1965, 2, 28)).description == "1965-2-28 UTC, TAI - UTC = 3.615298 s, drift 0.001296 s, step +0.1 s")
	}

	@Test func toTAIMatchesConversion() throws {
		let day = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		for reading in [0.0, 43_200, 86_400.5] {
			let direct = try day.toTAI(secondsSinceMidnight: reading)
			let converted = try Instant<UTC>(day.julianDate(secondsSinceMidnight: reading)).converted(to: TAI.self)
			#expect(direct.isApproximatelyEqual(to: converted.julianDate, toleranceSeconds: timescaleTolerance), "reading \(reading)")
		}
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) { try day.toTAI(secondsSinceMidnight: 86_401) }
	}

	@Test func containing() throws {
		let utc = try utcDate(civilDay(2016, 12, 31), seconds: 86_400.5)
		let day = try UTCDay(containing: utc)
		#expect(day.julianDayNumber == utc.julianDayNumber)
	}

	@Test func equality() throws {
		let j = try civilDay(2026, 10, 14)
		#expect(try UTCDay(julianDayNumber: j) == UTCDay(julianDayNumber: j))
		#expect(try UTCDay(julianDayNumber: j) != UTCDay(julianDayNumber: j + 1))
		#expect(try Set([UTCDay(julianDayNumber: j), UTCDay(julianDayNumber: j)]).count == 1)

		// Equality depends on the leap second table: with a leap second at the end of
		// 2027-06-30, that day differs from the built-in table's, and earlier days do not.
		let leapSecond = try LeapSecondTable.LeapSecond(effective: civilDay(2027, 7, 1), taiMinusUTC: 38)
		let table = try #require(LeapSecondTable(leapSeconds: LeapSecondTable.builtIn.leapSeconds + [leapSecond], horizon: civilDay(2028, 1, 1)))
		let lastDay = try civilDay(2027, 6, 30)
		#expect(try UTCDay(julianDayNumber: lastDay, leapSecondTable: table) != UTCDay(julianDayNumber: lastDay))
		#expect(try UTCDay(julianDayNumber: j, leapSecondTable: table) == UTCDay(julianDayNumber: j))
	}

	@Test func equalityIgnoresOffsetSource() throws {
		// The built-in leap seconds with a later horizon: 2027-07-01 is past the built-in
		// table's horizon but within this one's, and the days are equal.
		let builtIn = LeapSecondTable.builtIn
		let refreshed = try #require(LeapSecondTable(leapSeconds: builtIn.leapSeconds, horizon: civilDay(2028, 1, 1)))
		let j = try civilDay(2027, 7, 1)
		let extrapolated = try UTCDay(julianDayNumber: j, leapSecondTable: builtIn)
		let published = try UTCDay(julianDayNumber: j, leapSecondTable: refreshed)
		#expect(extrapolated.offsetSource == .extrapolation)
		#expect(published.offsetSource == .bulletin)
		#expect(extrapolated == published)
		#expect(Set([extrapolated, published]).count == 1)
	}
}
