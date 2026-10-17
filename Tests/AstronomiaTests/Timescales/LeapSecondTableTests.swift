//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// A line of https://maia.usno.navy.mil/ser7/tai-utc.dat.
struct TAIUTCLine: Sendable, CustomTestStringConvertible {
	let year: Int
	let month: Int
	let day: Int
	let offset: Double
	let referenceMJD: Int
	let rate: Double

	var testDescription: String { "\(year)-\(month)-\(day)" }
}

/// The contents of tai-utc.dat, transcribed independently of the built-in table.
let taiUTCLines: [TAIUTCLine] = [
	.init(year: 1961, month: 1, day: 1, offset: 1.4228180, referenceMJD: 37_300, rate: 0.001296),
	.init(year: 1961, month: 8, day: 1, offset: 1.3728180, referenceMJD: 37_300, rate: 0.001296),
	.init(year: 1962, month: 1, day: 1, offset: 1.8458580, referenceMJD: 37_665, rate: 0.0011232),
	.init(year: 1963, month: 11, day: 1, offset: 1.9458580, referenceMJD: 37_665, rate: 0.0011232),
	.init(year: 1964, month: 1, day: 1, offset: 3.2401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1964, month: 4, day: 1, offset: 3.3401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1964, month: 9, day: 1, offset: 3.4401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1965, month: 1, day: 1, offset: 3.5401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1965, month: 3, day: 1, offset: 3.6401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1965, month: 7, day: 1, offset: 3.7401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1965, month: 9, day: 1, offset: 3.8401300, referenceMJD: 38_761, rate: 0.001296),
	.init(year: 1966, month: 1, day: 1, offset: 4.3131700, referenceMJD: 39_126, rate: 0.002592),
	.init(year: 1968, month: 2, day: 1, offset: 4.2131700, referenceMJD: 39_126, rate: 0.002592),
	.init(year: 1972, month: 1, day: 1, offset: 10, referenceMJD: 41_317, rate: 0),
] + leapSeconds.map {
	TAIUTCLine(year: $0.year, month: $0.month, day: 1, offset: $0.taiMinusUTC, referenceMJD: 41_317, rate: 0)
}

@Suite struct LeapSecondTableTests {
	@Test func builtInMatchesTAIUTCDat() throws {
		// The rate segments before 1972, then whole-second leap seconds
		let segments = LeapSecondTable.RateSegment.all
		let leapSeconds = LeapSecondTable.builtIn.leapSeconds
		try #require(segments.count + leapSeconds.count == taiUTCLines.count)
		for (segment, line) in zip(segments, taiUTCLines) {
			// The segment applies from the midnight that starts the civil day `effective`.
			let effective = try civilDay(line.year, line.month, line.day)
			#expect(segment.effective == effective, "\(line.testDescription): effective")
			// MJD m starts at the midnight that begins civil day m + 2,400,001.
			#expect(segment.reference == line.referenceMJD + 2_400_001, "\(line.testDescription): reference")
			#expect(segment.offset == line.offset, "\(line.testDescription): offset")
			#expect(segment.rate == line.rate, "\(line.testDescription): rate")
		}
		for (leapSecond, line) in zip(leapSeconds, taiUTCLines.dropFirst(segments.count)) {
			#expect(try leapSecond.effective == civilDay(line.year, line.month, line.day), "\(line.testDescription): effective")
			#expect(Double(leapSecond.taiMinusUTC) == line.offset, "\(line.testDescription): offset")
			#expect(line.rate == 0, "\(line.testDescription): rate")
		}
	}

	@Test func builtInIsGenerated() throws {
		let table = LeapSecondTable.builtIn
		#expect(table.leapSeconds == builtInLeapSeconds)
		#expect(table.horizon == builtInLeapSecondsHorizon)
		#expect(try table.leapSeconds.first == LeapSecondTable.LeapSecond(effective: civilDay(1972, 1, 1), taiMinusUTC: 10))
	}

	@Test func entriesAreOrdered() throws {
		let segments = LeapSecondTable.RateSegment.all
		for (previous, next) in zip(segments, segments.dropFirst()) {
			#expect(previous.effective < next.effective)
		}
		#expect(segments.allSatisfy { $0.effective < LeapSecondTable.firstDayOf1972 && $0.rate > 0 })

		let table = LeapSecondTable.builtIn
		for (previous, next) in zip(table.leapSeconds, table.leapSeconds.dropFirst()) {
			#expect(previous.effective < next.effective)
		}
		let last = try #require(table.leapSeconds.last)
		#expect(table.horizon > last.effective)
	}

	@Test func segmentsStayInRange() {
		// TAI - UTC is linear in each segment, so it is in range if it is at both ends.
		let segments = LeapSecondTable.RateSegment.all
		let ends = segments.dropFirst().map(\.effective) + [LeapSecondTable.firstDayOf1972]
		for (segment, end) in zip(segments, ends) {
			for day in [segment.effective, end] {
				let offset = segment.taiMinusUTC(atStartOfUTCDay: day)
				#expect(offset > 0 && offset < 10)
			}
		}
	}

	@Test func lookupAtBoundaries() throws {
		let table = LeapSecondTable.builtIn
		let segments = LeapSecondTable.RateSegment.all
		#expect(table.taiMinusUTC(atStartOfUTCDay: segments[0].effective - 1) == nil)
		#expect(table.taiMinusUTC(atStartOfUTCDay: .min) == nil)

		for segment in segments {
			let value = try #require(table.taiMinusUTC(atStartOfUTCDay: segment.effective))
			#expect(value.seconds == segment.taiMinusUTC(atStartOfUTCDay: segment.effective))
			#expect(value.rate == segment.rate)
		}
		var previous: Int?
		for leapSecond in table.leapSeconds {
			#expect(table.taiMinusUTC(atStartOfUTCDay: leapSecond.effective)?.seconds == Double(leapSecond.taiMinusUTC))
			#expect(table.taiMinusUTC(atStartOfUTCDay: leapSecond.effective)?.rate == 0)
			if let previous {
				#expect(table.taiMinusUTC(atStartOfUTCDay: leapSecond.effective - 1)?.seconds == Double(previous))
			}
			previous = leapSecond.taiMinusUTC
		}
		#expect(table.taiMinusUTC(atStartOfUTCDay: .max)?.seconds == 37)
	}

	@Test func lookupByDate() throws {
		let table = LeapSecondTable.builtIn
		#expect(try table.taiMinusUTC(atStartOfUTCDay: civilDay(2016, 12, 31))?.seconds == 36)
		#expect(try table.taiMinusUTC(atStartOfUTCDay: civilDay(2017, 1, 1))?.seconds == 37)
		#expect(try table.taiMinusUTC(atStartOfUTCDay: civilDay(2026, 10, 14))?.seconds == 37)
		#expect(try table.taiMinusUTC(atStartOfUTCDay: civilDay(1960, 12, 31)) == nil)
	}

	@Test func driftFormula() throws {
		// TAI - UTC at 1965-06-15T00:00 UTC (MJD 38926) = 3.6401300 + 165 × 0.001296 s.
		let value = try #require(LeapSecondTable.builtIn.taiMinusUTC(atStartOfUTCDay: civilDay(1965, 6, 15)))
		#expect(abs(value.seconds - 3.853_97) <= 1e-12)
		#expect(value.rate == 0.001296)
	}

	@Test func stepInto1972() throws {
		// The last rate segment ends at 4.2131700 + (41316 - 39126) × 0.002592 = 9.88965 s at
		// the start of 1971-12-31, and the leap seconds begin at 10 s the next day.
		let table = LeapSecondTable.builtIn
		let last = try #require(table.taiMinusUTC(atStartOfUTCDay: civilDay(1971, 12, 31)))
		#expect(abs(last.seconds - 9.889_65) <= 1e-12)
		#expect(try table.taiMinusUTC(atStartOfUTCDay: civilDay(1972, 1, 1))?.seconds == 10)
	}
}
