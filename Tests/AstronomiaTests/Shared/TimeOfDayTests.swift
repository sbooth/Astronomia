//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TimeOfDayTests {
	@Test func validation() throws {
		#expect(throws: Never.self) { try TimeOfDay(hour: 0, minute: 0) }
		#expect(throws: Never.self) { try TimeOfDay(hour: 23, minute: 59, second: 60.5) }
		#expect(try TimeOfDay(hour: 1, minute: 2, second: -0.0).second.sign == .plus)
		// A leap second only in the last minute of the day
		#expect(throws: Never.self) { try TimeOfDay(hour: 12, minute: 34, second: Double(60).nextDown) }
		for (hour, minute, second) in [(12, 34, 60.5), (23, 58, 60), (0, 0, 60), (23, 59, 61)] {
			#expect(throws: TimeOfDayError.invalid) { try TimeOfDay(hour: hour, minute: minute, second: second) }
		}
		for (hour, minute, second) in [(24, 0, 0.0), (-1, 0, 0), (0, 60, 0), (0, -1, 0), (0, 0, 61), (0, 0, -0.001)] {
			#expect(throws: TimeOfDayError.invalid) { try TimeOfDay(hour: hour, minute: minute, second: second) }
		}
		#expect(throws: TimeOfDayError.nonFiniteValue) { try TimeOfDay(hour: 0, minute: 0, second: .nan) }
		#expect(throws: TimeOfDayError.nonFiniteValue) { try TimeOfDay(hour: 0, minute: 0, second: .infinity) }
	}

	@Test func secondsSinceMidnight() throws {
		#expect(try TimeOfDay(hour: 13, minute: 45, second: 30.25).secondsSinceMidnight == 49_530.25)
		#expect(try TimeOfDay(hour: 23, minute: 59, second: 60.5).secondsSinceMidnight == 86_400.5)
	}

	@Test(arguments: [0.0, 0.25, 59.999, 3_600, 49_530.25, 86_399.999_999])
	func decomposition(seconds: Double) {
		let time = TimeOfDay(uncheckedSecondsSinceMidnight: seconds)
		#expect((0 ..< 24).contains(time.hour) && (0 ..< 60).contains(time.minute))
		#expect(time.second >= 0 && time.second < 60)
		#expect(time.secondsSinceMidnight == seconds)
	}

	@Test func leapSecondDecomposition() {
		// Past 86,400 s the hour and minute stop, and the second passes 60.
		let time = TimeOfDay(uncheckedSecondsSinceMidnight: 86_400.75)
		#expect(time.hour == 23 && time.minute == 59 && time.second == 60.75)
	}
}
