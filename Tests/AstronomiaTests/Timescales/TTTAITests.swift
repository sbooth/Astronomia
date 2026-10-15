//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TTTests {
	@Test(arguments: sampleDates)
	func toAndFromTTAreIdentity(date: JulianDate) throws {
		#expect(try TT.toTT(date) == date)
		#expect(try TT.fromTT(date) == date)
	}

	@Test func offsetFromTAI() {
		#expect(TT.offsetFromTAI == 32.184)
		#expect(TT.intervalFromTAI.days == 0)
		#expect(TT.intervalFromTAI.fractionalDay == 32.184 / 86_400)
	}
}

@Suite struct TAITests {
	@Test func offsetAtJ2000() throws {
		// J2000.0 TAI is 2000-01-01T12:00:32.184 TT.
		let tt = try Instant<TAI>(.J2000).converted(to: TT.self)
		#expect(tt.julianDate.julianDayNumber == JulianDate.J2000.julianDayNumber)
		#expect(try abs(seconds(from: .J2000, to: tt.julianDate) - 32.184) <= timescaleTolerance)
	}

	@Test(arguments: sampleDates)
	func ttMinusTAI(date: JulianDate) throws {
		let tt = try TAI.toTT(date)
		#expect(try abs(seconds(from: date, to: tt) - 32.184) <= timescaleTolerance)
		let tai = try TAI.fromTT(date)
		#expect(try abs(seconds(from: tai, to: date) - 32.184) <= timescaleTolerance)
	}

	@Test(arguments: sampleDates)
	func roundTrip(date: JulianDate) throws {
		try expectRoundTrip(TAI.self, TT.self, date: date)
		try expectRoundTrip(TT.self, TAI.self, date: date)
	}

	@Test func crossesMidnight() throws {
		// 23:59:50 TAI is 00:00:22.184 TT the next day.
		let day = try civilDay(2026, 10, 14)
		let tt = try TAI.toTT(uniformDate(day, seconds: 86_390))
		#expect(tt.julianDayNumber == day + 1)
		#expect(try tt.isApproximatelyEqual(to: uniformDate(day + 1, seconds: 22.184), toleranceSeconds: timescaleTolerance))
	}

	@Test func outOfRange() throws {
		let latest = try JulianDate(julianDayNumber: .max, fractionFromNoon: 0.499_9)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TAI.toTT(latest)
		}
		let earliest = try JulianDate(julianDayNumber: .min, fractionFromNoon: -0.499_9)
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try TAI.fromTT(earliest)
		}
	}
}
