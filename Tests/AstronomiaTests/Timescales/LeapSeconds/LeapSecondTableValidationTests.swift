//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LeapSecondTableValidationTests {
	typealias LeapSecond = LeapSecondTable.LeapSecond

	/// 1972-01-01, the first leap second entry.
	let start = 2_441_318
	/// 1972-07-01
	let july = 2_441_500

	@Test func builtInIsValid() {
		let table = LeapSecondTable.builtIn
		#expect(LeapSecondTable(leapSeconds: table.leapSeconds, horizon: table.horizon) == table)
	}

	@Test func validCustomTable() throws {
		// The built-in table plus a fictitious leap second on 2027-07-01.
		let leapSeconds = LeapSecondTable.builtIn.leapSeconds + [LeapSecond(effectiveDay: 2_461_588, taiMinusUTC: 38)]
		let table = try #require(LeapSecondTable(leapSeconds: leapSeconds, horizon: 2_461_772))
		#expect(table.leapSeconds == leapSeconds)
		#expect(table.horizon == 2_461_772)
	}

	@Test func notStartingIn1972() {
		#expect(LeapSecondTable(leapSeconds: [LeapSecond(effectiveDay: start, taiMinusUTC: 10)], horizon: start + 1) != nil)
		#expect(LeapSecondTable(leapSeconds: [], horizon: start + 1) == nil)
		#expect(LeapSecondTable(leapSeconds: [LeapSecond(effectiveDay: july, taiMinusUTC: 11)], horizon: july + 1) == nil)
		#expect(LeapSecondTable(leapSeconds: [LeapSecond(effectiveDay: start, taiMinusUTC: 11)], horizon: start + 1) == nil)
		#expect(LeapSecondTable(leapSeconds: [LeapSecond(effectiveDay: start - 1, taiMinusUTC: 10)], horizon: start + 1) == nil)
	}

	@Test func notInIncreasingOrder() {
		for second in [start, start - 1] {
			let leapSeconds = [LeapSecond(effectiveDay: start, taiMinusUTC: 10), LeapSecond(effectiveDay: second, taiMinusUTC: 11)]
			#expect(LeapSecondTable(leapSeconds: leapSeconds, horizon: july) == nil)
		}
	}

	@Test func horizonNotAfterLastEntry() {
		let leapSeconds = [LeapSecond(effectiveDay: start, taiMinusUTC: 10), LeapSecond(effectiveDay: july, taiMinusUTC: 11)]
		for horizon in [july, july - 1] {
			#expect(LeapSecondTable(leapSeconds: leapSeconds, horizon: horizon) == nil)
		}
	}

	@Test func stepsOfOneSecond() {
		// A positive or a negative leap second
		for offset in [11, 9] {
			let leapSeconds = [LeapSecond(effectiveDay: start, taiMinusUTC: 10), LeapSecond(effectiveDay: july, taiMinusUTC: offset)]
			#expect(LeapSecondTable(leapSeconds: leapSeconds, horizon: july + 1) != nil)
		}
		// No change, or a change of more than a second, is not a leap second.
		for offset in [10, 12, 8, 50, -1, 86_400, .max, .min] {
			let leapSeconds = [LeapSecond(effectiveDay: start, taiMinusUTC: 10), LeapSecond(effectiveDay: july, taiMinusUTC: offset)]
			#expect(LeapSecondTable(leapSeconds: leapSeconds, horizon: july + 1) == nil, "\(offset)")
		}
	}

	@Test func offsetOutOfRange() {
		// Ten negative leap seconds from 10 s reach 0 s; an eleventh would make it negative.
		let tenDown = (0 ... 10).map { LeapSecond(effectiveDay: start + 183 * $0, taiMinusUTC: 10 - $0) }
		#expect(LeapSecondTable(leapSeconds: tenDown, horizon: start + 183 * 11) != nil)
		let elevenDown = (0 ... 11).map { LeapSecond(effectiveDay: start + 183 * $0, taiMinusUTC: 10 - $0) }
		#expect(LeapSecondTable(leapSeconds: elevenDown, horizon: start + 183 * 12) == nil)
	}
}
