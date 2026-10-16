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
		#expect(all.deltaTAndPredictionStatus(at: all.range.upperBound)?.isPredicted == true)

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
