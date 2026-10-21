//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// A UT1 context with observations around the end of 2016 and no model.
func observedContext() throws -> UT1.Context {
	let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
	return UT1.Context(earthOrientationTable: table, model: nil)
}

@Suite struct DeltaTModelTests {
	/// ΔT from the Espenak & Meeus (2006) polynomials, evaluated independently.
	@Test(arguments: [
		(-1000.0, 25427.68), (-500, 17203.6563390625), (0, 10583.6), (1000, 1574.2),
		(1600, 120.0), (1650, 50.194015991022596), (1700, 8.83), (1750, 13.370070272572404),
		(1800, 13.72), (1830, 7.673379999999991), (1860, 7.62), (1880, -5.00848698849785),
		(1900, -2.79), (1910, 10.388399999999999), (1920, 21.2), (1930, 24.1329),
		(1941, 24.773141433749377), (1950, 29.07), (1961, 33.579880865652456), (1975, 45.45),
		(1986, 54.87773753824), (2000, 63.86), (2005, 64.670575), (2026.5, 75.38238025),
		(2050, 93.0), (2100, 202.74), (2150, 328.48), (2500, 1459.68),
	])
	func espenakMeeus2006(year: Double, deltaT: Double) {
		let value = DeltaTModel.espenakMeeus2006.deltaT(decimalYear: year)
		#expect(abs(value - deltaT) <= 1e-9 * max(1, abs(deltaT)), "\(year)")
	}
}

@Suite struct UT1Tests {
	@Test(arguments: [
		(2016, 12, 31, -0.4077601),
		(2017, 1, 1, 0.5912821),
		(2017, 1, 2, 0.5901752),
	])
	func ut1MinusUTCAtEntries(year: Int, month: Int, day: Int, ut1MinusUTC: Double) throws {
		let j = try civilDay(year, month, day)
		let ut1 = try Instant<UTC>(utcDate(j)).converted(to: UT1.self, targetContext: observedContext())
		#expect(try abs(seconds(from: uniformDate(j), to: ut1.julianDate) - ut1MinusUTC) <= timescaleTolerance)
	}

	@Test func interpolatesWithinDay() throws {
		// Midway through 2017-01-01, UT1 - UTC is midway between the entries.
		let j = try civilDay(2017, 1, 1)
		let ut1 = try Instant<UTC>(utcDate(j, seconds: 43_200)).converted(to: UT1.self, targetContext: observedContext())
		#expect(try abs(seconds(from: uniformDate(j, seconds: 43_200), to: ut1.julianDate) - 0.590_728_65) <= timescaleTolerance)
	}

	@Test func interpolatesAcrossLeapSecond() throws {
		// 2016-12-31 lasts 86,401 s. At 12:00:00 UTC, 43,200 of them have elapsed, so ΔT is
		// 43,200 / 86,401 of the way between the entries and UT1 - UTC has no one-second jump.
		let j = try civilDay(2016, 12, 31)
		let ut1 = try Instant<UTC>(utcDate(j, seconds: 43_200)).converted(to: UT1.self, targetContext: observedContext())
		#expect(try abs(seconds(from: uniformDate(j, seconds: 43_200), to: ut1.julianDate) - -0.408_238_994_457) <= timescaleTolerance)
	}

	@Test func toTTWithObservations() throws {
		// 0h UTC on 2017-01-01: UT1 = 00:00:00.5912821, TT = 00:01:09.184.
		let j = try civilDay(2017, 1, 1)
		let ut1 = Instant<UT1>(try uniformDate(j, seconds: 0.591_282_1))
		let tt = try ut1.converted(to: TT.self, sourceContext: observedContext())
		#expect(try tt.julianDate.isApproximatelyEqual(to: uniformDate(j, seconds: 69.184), toleranceSeconds: timescaleTolerance))
	}

	@Test func roundTripWithObservations() throws {
		let context = try observedContext()
		let start = try uniformDate(civilDay(2016, 12, 29), seconds: 3_600)
		for step in 0 ..< 16 {
			let tt = try start.adding(seconds: Double(step) * 20_000)
			let ut1 = try UT1.fromTT(tt, context: context)
			#expect(try UT1.toTT(ut1, context: context).isApproximatelyEqual(to: tt, toleranceSeconds: timescaleTolerance), "step \(step)")
		}
	}

	@Test func utcRoundTripWithObservations() throws {
		let context = try observedContext()
		let utc = Instant<UTC>(try utcDate(civilDay(2016, 12, 31), seconds: 86_400.5))
		let ut1 = try utc.converted(to: UT1.self, targetContext: context)
		let back = try ut1.converted(to: UTC.self, sourceContext: context)
		#expect(back.julianDate.julianDayNumber == utc.julianDate.julianDayNumber)
		#expect(try abs(clockReading(back.julianDate) - 86_400.5) <= timescaleTolerance)
	}

	@Test func modernTableByDefault() throws {
		// 2000-01-01T00:00 TT is an entry of the modern table, ΔT = 63.8285 s.
		let tt = try uniformDate(civilDay(2000, 1, 1))
		let ut1 = try Instant<TT>(tt).converted(to: UT1.self)
		#expect(try abs(seconds(from: ut1.julianDate, to: tt) - 63.8285) <= timescaleTolerance)
	}

	@Test func tablesOutsideObservations() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let tt = try uniformDate(civilDay(2000, 1, 1))

		let withTables = UT1.Context(earthOrientationTable: table)
		#expect(try abs(UT1.deltaT(at: tt, context: withTables) - 63.8285) <= timescaleTolerance)
		let continuous = UT1.Context.continuous(earthOrientationTable: table)
		#expect(try abs(UT1.deltaT(at: tt, context: continuous) - 63.8285) <= timescaleTolerance)

		let observationsOnly = UT1.Context(earthOrientationTable: table, deltaTTable: nil, model: nil)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.fromTT(tt, context: observationsOnly)
		}
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.deltaT(at: tt, context: UT1.Context(deltaTTable: nil, model: nil))
		}
	}

	@Test(arguments: sampleDates)
	func roundTripWithModel(date: JulianDate) throws {
		try expectRoundTrip(UT1.self, TT.self, date: date)
		try expectRoundTrip(TT.self, UT1.self, date: date)
	}

	@Test(arguments: utcSampleDates)
	func roundTripWithUTC(date: JulianDate) throws {
		try expectRoundTrip(UTC.self, UT1.self, date: date)
	}
}
