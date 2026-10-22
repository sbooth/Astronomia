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

/// Rows of IERS `finals2000A.all` from December 2020, where the nutation values turn to
/// predictions before UT1 - UTC and polar motion do, and the excess length of day ends.
let finalsWithPredictedNutation = """
2012 8 59191.00 I  0.095365 0.000023  0.289712 0.000023  I-0.1779703 0.0000145  0.4328 0.0104  I     0.090    0.128     0.153    0.160
2012 9 59192.00 I  0.093365 0.000021  0.289644 0.000020  I-0.1784968 0.0000177  0.5946 0.0113  P     0.091    0.111     0.154    0.145
201217 59200.00 I  0.082965 0.000091  0.293991 0.000093  I-0.1791644 0.0000552                 P     0.133    0.127     0.191    0.159
201218 59201.00 P  0.081813 0.000601  0.294572 0.000448  P-0.1787602 0.0001080                 P     0.142    0.127     0.195    0.159
"""

@Suite struct EarthOrientationTableTests {
	@Test func parseFinals2000A() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		#expect(table.entries.count == 5)
		#expect(try table.entries.first?.utcDay == civilDay(2016, 12, 29))
		#expect(table.entries.first?.ut1MinusUTC == -0.4060885)
		#expect(try table.entries.last?.utcDay == civilDay(2017, 1, 2))
		#expect(table.entries.last?.ut1MinusUTC == 0.5901752)
		#expect(table.entries.allSatisfy { !$0.isPredicted })
	}

	@Test func parsePredictionsAndBlankRows() throws {
		let all = try #require(EarthOrientationTable(finals2000A: finalsWithPrediction))
		#expect(all.entries.count == 2, "the row without a value is skipped")
		#expect(all.entries.map(\.isPredicted) == [false, true])
		#expect(all.deltaTAndPredictionStatus(at: all.coverage.upperBound)?.isPredicted == true)

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

	@Test func coverage() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		// 0h UTC on 2016-12-29 is 00:01:08.184 TT; 0h UTC on 2017-01-02 is 00:01:09.184 TT.
		#expect(try table.coverage.lowerBound.isApproximatelyEqual(to: uniformDate(civilDay(2016, 12, 29), seconds: 68.184), toleranceSeconds: timescaleTolerance))
		#expect(try table.coverage.upperBound.isApproximatelyEqual(to: uniformDate(civilDay(2017, 1, 2), seconds: 69.184), toleranceSeconds: timescaleTolerance))
		#expect(try table.deltaT(atTT: uniformDate(civilDay(2016, 12, 28))) == nil)
		#expect(try table.deltaT(atTT: uniformDate(civilDay(2017, 1, 3))) == nil)
	}

	@Test func parseParameters() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let first = table.entries[0]
		#expect(first.polarMotion == PolarMotion(x: Angle(arcseconds: 0.084635), y: Angle(arcseconds: 0.264193)))
		#expect(first.celestialPoleOffsets == CelestialPoleOffsets(dX: Angle(milliarcseconds: 0.003), dY: Angle(milliarcseconds: -0.139)))
		#expect(first.excessLengthOfDay == 0.8162 / 1000)
		#expect(table.entries.allSatisfy { $0.polarMotion != nil && $0.celestialPoleOffsets != nil && $0.excessLengthOfDay != nil })

		// Rows that end after UT1 - UTC have no other values.
		let short = try #require(EarthOrientationTable(finals2000A: finalsWithPrediction))
		#expect(short.entries.map(\.polarMotion?.isPredicted) == [false, true])
		#expect(short.entries.allSatisfy { $0.celestialPoleOffsets == nil && $0.excessLengthOfDay == nil })
	}

	@Test func parsePredictedParameters() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsWithPredictedNutation))
		#expect(table.entries.map(\.isPredicted) == [false, false, false, true])
		#expect(table.entries.map(\.polarMotion?.isPredicted) == [false, false, false, true])
		#expect(table.entries.map(\.celestialPoleOffsets?.isPredicted) == [false, true, true, true])
		#expect(table.entries.map { $0.excessLengthOfDay != nil } == [true, true, false, false])

		// Without predictions, the last row is skipped and the predicted offsets are left out.
		let observed = try #require(EarthOrientationTable(finals2000A: finalsWithPredictedNutation, includePredictions: false))
		#expect(observed.entries.count == 3)
		#expect(observed.entries.map { $0.polarMotion != nil } == [true, true, true])
		#expect(observed.entries.map { $0.celestialPoleOffsets != nil } == [true, false, false])
	}

	@Test func rejectsMalformedParameters() throws {
		let row = "161231 57753.00 I  0.081400 0.000052  0.263094 0.000039  I-0.4077601 0.0000078  0.8842 0.0055  I     0.025    0.119    -0.169    0.024"
		let next = "17 1 1 57754.00 I  0.080504 0.000028  0.263145 0.000028  I 0.5912821 0.0000077  1.0342 0.0050  I     0.012    0.119    -0.168    0.018"
		#expect(EarthOrientationTable(finals2000A: row + "\n" + next) != nil)

		/// Returns `row` with columns `range`, 1-based and inclusive, replaced by `text`.
		func replacing(_ range: ClosedRange<Int>, with text: String) -> String {
			var characters = Array(row)
			let padded = Array(text) + Array(repeating: " ", count: range.count - text.count)
			characters.replaceSubrange((range.lowerBound - 1) ..< range.upperBound, with: padded)
			return String(characters)
		}
		// Only one coordinate of a pair, or a value that is not a number
		#expect(EarthOrientationTable(finals2000A: replacing(19 ... 27, with: "") + "\n" + next) == nil)
		#expect(EarthOrientationTable(finals2000A: replacing(117 ... 125, with: "") + "\n" + next) == nil)
		#expect(EarthOrientationTable(finals2000A: replacing(80 ... 86, with: "0.88x2") + "\n" + next) == nil)

		let day = try civilDay(2017, 1, 1)
		let infinite = PolarMotion(x: Angle(arcseconds: .infinity), y: .zero)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0, polarMotion: infinite), .init(utcDay: day + 1, ut1MinusUTC: 0)]) == nil)
		let nan = CelestialPoleOffsets(dX: .zero, dY: Angle(radians: .nan))
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0, celestialPoleOffsets: nan), .init(utcDay: day + 1, ut1MinusUTC: 0)]) == nil)
		#expect(EarthOrientationTable(entries: [.init(utcDay: day, ut1MinusUTC: 0, excessLengthOfDay: .nan), .init(utcDay: day + 1, ut1MinusUTC: 0)]) == nil)
	}

	@Test func interpolatesParameters() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		// Midway between 0h UTC on 2016-12-29 and 2016-12-30, both 68.184 s before 0h TT
		let midway = try table.samples[0].tt.adding(days: 0.5)
		let pole = try #require(table.polarMotion(at: midway))
		#expect(abs(pole.x.arcseconds - (0.084635 + 0.082883) / 2) <= 1e-12)
		#expect(abs(pole.y.arcseconds - (0.264193 + 0.263539) / 2) <= 1e-12)
		#expect(!pole.isPredicted)
		let offsets = try #require(table.celestialPoleOffsets(at: midway))
		#expect(abs(offsets.dX.milliarcseconds - (0.003 + 0.022) / 2) <= 1e-12)
		#expect(abs(offsets.dY.milliarcseconds - (-0.139 + -0.155) / 2) <= 1e-12)
		let lod = try #require(table.excessLengthOfDay(at: midway))
		#expect(abs(lod - (0.8162 + 0.8286) / 2000) <= 1e-15)

		// At an entry, its values exactly; outside the table, none
		let last = table.entries[table.entries.count - 1]
		#expect(table.polarMotion(at: table.coverage.upperBound) == last.polarMotion)
		#expect(table.celestialPoleOffsets(at: table.coverage.upperBound) == last.celestialPoleOffsets)
		#expect(table.excessLengthOfDay(at: table.coverage.upperBound) == last.excessLengthOfDay)
		#expect(table.polarMotion(at: table.samples[1].tt) == table.entries[1].polarMotion)
		#expect(try table.polarMotion(at: uniformDate(civilDay(2016, 12, 28))) == nil)
		#expect(try table.celestialPoleOffsets(at: uniformDate(civilDay(2017, 1, 3))) == nil)
	}

	@Test func parametersNeedBothNeighbors() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsWithPredictedNutation))
		// Between an observed and a predicted value, the result is predicted.
		let first = try table.samples[0].tt.adding(days: 0.5)
		#expect(table.polarMotion(at: first)?.isPredicted == false)
		#expect(table.celestialPoleOffsets(at: first)?.isPredicted == true)
		let last = try table.samples[2].tt.adding(days: 0.5)
		#expect(table.polarMotion(at: last)?.isPredicted == true)

		// The 2020-12-17 row has no excess length of day, so there is none after 2020-12-09,
		// except at that entry itself.
		#expect(table.excessLengthOfDay(at: first) != nil)
		#expect(try table.excessLengthOfDay(at: table.samples[1].tt.adding(days: 1)) == nil)
		#expect(table.excessLengthOfDay(at: table.samples[1].tt) == 0.5946 / 1000)
	}
}
