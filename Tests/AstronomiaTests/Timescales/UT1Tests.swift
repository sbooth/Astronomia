//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Rows of IERS `finals2000A.all` around the leap second at the end of 2016.
let finalsAroundLeapSecond = """
161229 57751.00 I  0.084635 0.000052  0.264193 0.000037  I-0.4060885 0.0000079  0.8162 0.0055  I     0.003    0.119    -0.139    0.024  0.084589  0.264175 -0.4060935    -0.024    -0.029
161230 57752.00 I  0.082883 0.000052  0.263539 0.000038  I-0.4069180 0.0000079  0.8286 0.0056  I     0.022    0.119    -0.155    0.024  0.082924  0.263518 -0.4069106    -0.023    -0.038
161231 57753.00 I  0.081400 0.000052  0.263094 0.000039  I-0.4077601 0.0000078  0.8842 0.0055  I     0.025    0.119    -0.169    0.024  0.081318  0.262990 -0.4077600    -0.021    -0.048
17 1 1 57754.00 I  0.080504 0.000028  0.263145 0.000028  I 0.5912821 0.0000077  1.0342 0.0050  I     0.012    0.119    -0.168    0.018  0.080450  0.263074  0.5912975    -0.019    -0.057
17 1 2 57755.00 I  0.080285 0.000029  0.263605 0.000032  I 0.5901752 0.0000063  1.1730 0.0048  I    -0.001    0.040    -0.156    0.033  0.080275  0.263595  0.5902149    -0.027    -0.065
"""

/// Rows of IERS `finals2000A.all` with an observation, a prediction, and a row with no value.
let finalsWithPrediction = """
2012 3 59186.00 I  0.104564 0.000092  0.287542 0.000094  I-0.1783084 0.0000184
2012 4 59187.00 P  0.102993 0.000603  0.287625 0.000412  P-0.1778707 0.0001080
22 130 59609.00
"""

/// A UT1 context with observations around the end of 2016 and no model.
func observedContext() throws -> UT1.Context {
	let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
	return UT1.Context(earthOrientation: table, model: nil)
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

@Suite struct EarthOrientationTableTests {
	@Test func parseFinals2000A() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		#expect(table.entries.count == 5)
		#expect(try table.entries.first == EarthOrientationTable.Entry(utcDay: civilDay(2016, 12, 29), ut1MinusUTC: -0.4060885))
		#expect(try table.entries.last == EarthOrientationTable.Entry(utcDay: civilDay(2017, 1, 2), ut1MinusUTC: 0.5901752))
		#expect(table.entries.allSatisfy { !$0.isPredicted })
	}

	@Test func parsePredictionsAndBlankRows() throws {
		let all = try #require(EarthOrientationTable(finals2000A: finalsWithPrediction))
		#expect(all.entries.count == 2, "the row without a value is skipped")
		#expect(all.entries.map(\.isPredicted) == [false, true])
		#expect(all.deltaT(at: all.range.upperBound)?.isPredicted == true)

		// Without the prediction only one entry remains, too few for a table.
		#expect(EarthOrientationTable(finals2000A: finalsWithPrediction, includePredictions: false) == nil)
	}

	@Test func rejectsInvalidEntries() throws {
		let day = try civilDay(2017, 1, 1)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0)]) == nil)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0), .init(utcDay: day, ut1MinusUTC: 0)]) == nil)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0), .init(utcDay: day + 1, ut1MinusUTC: 1.2)]) == nil)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: .nan), .init(utcDay: day + 1, ut1MinusUTC: 0)]) == nil)
		// Before 1961, TAI - UTC is not defined.
		let early = try civilDay(1960, 1, 1)
		#expect(EarthOrientationTable(entries: [.init(utcDay: early, ut1MinusUTC: 0), .init(utcDay: early + 1, ut1MinusUTC: 0)]) == nil)
		#expect(EarthOrientationTable(finals2000A: "161231 5775x.00 I  0.081400 0.000052  0.263094 0.000039  I-0.4077601 0.0000078") == nil)
	}

	@Test func deltaTIsContinuousAcrossLeapSecond() throws {
		// ΔT = 32.184 s + (TAI - UTC) - (UT1 - UTC) at 0h UTC.
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let expected = [68.5900885, 68.590918, 68.5917601, 68.5927179, 68.5938248]
		for (sample, deltaT) in zip(table.samples, expected) {
			#expect(abs(sample.deltaT - deltaT) <= 1e-9)
		}
		// UT1 - UTC jumps by a second; ΔT changes by about a millisecond per day.
		for (a, b) in zip(table.samples, table.samples.dropFirst()) {
			#expect(abs(b.deltaT - a.deltaT) < 2e-3)
		}
	}

	@Test func range() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		// 0h UTC on 2016-12-29 is 00:01:08.184 TT; 0h UTC on 2017-01-02 is 00:01:09.184 TT.
		#expect(try table.range.lowerBound.isApproximatelyEqual(to: uniformDate(civilDay(2016, 12, 29), seconds: 68.184), toleranceSeconds: timescaleTolerance))
		#expect(try table.range.upperBound.isApproximatelyEqual(to: uniformDate(civilDay(2017, 1, 2), seconds: 69.184), toleranceSeconds: timescaleTolerance))
		#expect(try table.deltaT(at: uniformDate(civilDay(2016, 12, 28))) == nil)
		#expect(try table.deltaT(at: uniformDate(civilDay(2017, 1, 3))) == nil)
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

	@Test func modelByDefault() throws {
		// 2000-01-01T00:00 TT is decimal year 2000.0, where the model gives ΔT = 63.86 s.
		let tt = try uniformDate(civilDay(2000, 1, 1))
		let ut1 = try Instant<TT>(tt).converted(to: UT1.self)
		#expect(try abs(seconds(from: ut1.julianDate, to: tt) - 63.86) <= timescaleTolerance)
	}

	@Test func modelOutsideObservations() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let tt = try uniformDate(civilDay(2000, 1, 1))

		let withModel = UT1.Context(earthOrientation: table)
		#expect(try abs(UT1.deltaT(at: tt, context: withModel) - 63.86) <= timescaleTolerance)

		let observationsOnly = UT1.Context(earthOrientation: table, model: nil)
		#expect(throws: TimescaleConversionError.earthOrientationDataUnavailable) {
			try UT1.fromTT(tt, context: observationsOnly)
		}
		#expect(throws: TimescaleConversionError.earthOrientationDataUnavailable) {
			try UT1.deltaT(at: tt, context: UT1.Context(model: nil))
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
