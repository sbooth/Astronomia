//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LeapSecondTableValidationTests {
	typealias Entry = LeapSecondTable.Entry

	/// 2017-01-01, the last built-in entry.
	let day = 2_457_755

	@Test func builtInIsValid() {
		let table = LeapSecondTable.builtIn
		#expect(LeapSecondTable(entries: table.entries, horizon: table.horizon) == table)
	}

	@Test func validCustomTable() throws {
		// The built-in table plus a fictitious leap second on 2027-07-01.
		let entries = LeapSecondTable.builtIn.entries + [Entry(effective: 2_461_588, offset: 38, reference: 2_441_318, rate: 0)]
		let table = try #require(LeapSecondTable(entries: entries, horizon: 2_461_772))
		#expect(table.entries == entries)
		#expect(table.horizon == 2_461_772)
	}

	@Test func noEntries() {
		#expect(LeapSecondTable(entries: [], horizon: day) == nil)
	}

	@Test func nonFiniteValues() {
		for (offset, rate) in [(Double.nan, 0.0), (.infinity, 0), (37, .nan), (37, -.infinity)] {
			#expect(LeapSecondTable(entries: [Entry(effective: day, offset: offset, reference: day, rate: rate)], horizon: day + 1) == nil)
		}
	}

	@Test func notInIncreasingOrder() {
		for second in [day, day - 1] {
			let entries = [Entry(effective: day, offset: 36, reference: day, rate: 0), Entry(effective: second, offset: 37, reference: day, rate: 0)]
			#expect(LeapSecondTable(entries: entries, horizon: day + 1) == nil)
		}
	}

	@Test func lastEntryDrifts() {
		#expect(LeapSecondTable(entries: [Entry(effective: day, offset: 37, reference: day, rate: 0.001)], horizon: day + 1) == nil)
	}

	@Test func horizonNotAfterLastEntry() {
		for horizon in [day, day - 1] {
			#expect(LeapSecondTable(entries: [Entry(effective: day, offset: 37, reference: day, rate: 0)], horizon: horizon) == nil)
		}
	}

	@Test func offsetOutOfRange() {
		// Negative, or a day or more, where the entry takes effect.
		for offset in [-1.0, 86_400, 1e300] {
			#expect(LeapSecondTable(entries: [Entry(effective: day, offset: offset, reference: day, rate: 0)], horizon: day + 1) == nil)
		}

		// In range where the first entry takes effect, but drifting below zero by the time
		// the second entry takes effect: 1 s - 1,000 days × 0.002 s/day = -1 s.
		let drifting = [Entry(effective: day, offset: 1, reference: day, rate: -0.002), Entry(effective: day + 1_000, offset: 2, reference: day, rate: 0)]
		#expect(LeapSecondTable(entries: drifting, horizon: day + 1_001) == nil)

		// A reference so far away that `day - reference` overflows `Int` must be rejected,
		// not trap.
		let farReference = [Entry(effective: day, offset: 37, reference: .min, rate: 1), Entry(effective: day + 1, offset: 37, reference: day, rate: 0)]
		#expect(LeapSecondTable(entries: farReference, horizon: day + 2) == nil)
	}
}
