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
		let entries = LeapSecondTable.builtIn.entries
		try #require(entries.count == taiUTCLines.count)
		for (entry, line) in zip(entries, taiUTCLines) {
			// The entry applies from the midnight that starts the civil day `effective`.
			let effective = try civilDay(line.year, line.month, line.day)
			#expect(entry.effective == effective, "\(line.testDescription): effective")
			// MJD m starts at the midnight that begins civil day m + 2,400,001.
			#expect(entry.reference == line.referenceMJD + 2_400_001, "\(line.testDescription): reference")
			#expect(entry.offset == line.offset, "\(line.testDescription): offset")
			#expect(entry.rate == line.rate, "\(line.testDescription): rate")
		}
	}

	@Test func entriesAreOrdered() throws {
		let table = LeapSecondTable.builtIn
		for (previous, next) in zip(table.entries, table.entries.dropFirst()) {
			#expect(previous.effective < next.effective)
		}
		let last = try #require(table.entries.last)
		#expect(table.horizon > last.effective)
	}

	@Test func lookupAtEntryBoundaries() throws {
		let table = LeapSecondTable.builtIn
		let first = try #require(table.entries.first)
		#expect(table.entryForUTCJulianDayNumber(first.effective - 1) == nil)
		#expect(table.entryForUTCJulianDayNumber(.min) == nil)

		var previous: LeapSecondTable.Entry?
		for entry in table.entries {
			#expect(table.entryForUTCJulianDayNumber(entry.effective) == entry)
			#expect(table.entryForUTCJulianDayNumber(entry.effective - 1) == previous)
			previous = entry
		}
		#expect(table.entryForUTCJulianDayNumber(.max) == table.entries.last)
	}

	@Test func lookupByDate() throws {
		let table = LeapSecondTable.builtIn
		#expect(try table.entryForUTCJulianDayNumber(civilDay(2016, 12, 31))?.offset == 36)
		#expect(try table.entryForUTCJulianDayNumber(civilDay(2017, 1, 1))?.offset == 37)
		#expect(try table.entryForUTCJulianDayNumber(civilDay(2026, 10, 14))?.offset == 37)
		#expect(try table.entryForUTCJulianDayNumber(civilDay(1960, 12, 31)) == nil)
	}

	@Test func driftFormula() throws {
		// TAI - UTC at 1965-06-15T00:00 UTC (MJD 38926) = 3.6401300 + 165 × 0.001296 s.
		let day = try civilDay(1965, 6, 15)
		let entry = try #require(LeapSecondTable.builtIn.entryForUTCJulianDayNumber(day))
		let offset = entry.taiMinusUTC(atStartOfUTCDay: day)
		#expect(abs(offset - 3.853_97) <= 1e-12)
	}
}
