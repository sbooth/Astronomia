//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct UTCDayTimeOfDayTests {
	@Test func leapSecond() throws {
		let day = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		let leap = try TimeOfDay(hour: 23, minute: 59, second: 60.5)
		let utc = try day.julianDate(leap)
		#expect(try abs(day.secondsSinceMidnight(utc) - 86_400.5) <= timescaleTolerance)

		let back = try day.timeOfDay(utc)
		#expect(back.hour == 23 && back.minute == 59)
		#expect(abs(back.second - 60.5) <= timescaleTolerance)

		// The same Julian Date as a calendar date assumes 86,400 s and cannot show 23:59:60.
		#expect(utc.calendarDate.second < 60)
	}

	@Test func ordinaryDay() throws {
		let day = try UTCDay(julianDayNumber: civilDay(2026, 10, 16))
		let time = try TimeOfDay(hour: 13, minute: 45, second: 30.25)
		let utc = try day.julianDate(time)
		let back = try day.timeOfDay(utc)
		#expect(back.hour == 13 && back.minute == 45)
		#expect(abs(back.second - 30.25) <= timescaleTolerance)
		// On a day of 86,400 s, the calendar date agrees.
		#expect(utc.calendarDate.hour == 13 && utc.calendarDate.minute == 45)
		#expect(abs(utc.calendarDate.second - 30.25) <= timescaleTolerance)
	}

	@Test func errors() throws {
		let ordinary = try UTCDay(julianDayNumber: civilDay(2026, 10, 16))
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try ordinary.julianDate(TimeOfDay(hour: 23, minute: 59, second: 60))
		}
		let other = try UTCDay(julianDayNumber: civilDay(2026, 10, 17)).start
		#expect(throws: TimescaleConversionError.dateOutOfRange) {
			try ordinary.timeOfDay(other)
		}
	}

	@Test func lastInstantOfDay() throws {
		// 23:59:59.999… sums to 86,400 s, but is before midnight on an ordinary day.
		let day = try UTCDay(julianDayNumber: civilDay(2026, 10, 16))
		let time = try TimeOfDay(hour: 23, minute: 59, second: Double(60).nextDown)
		let utc = try day.julianDate(time)
		#expect(utc.julianDayNumber == day.julianDayNumber)
		let back = try day.timeOfDay(utc)
		#expect(back.hour == 23 && back.minute == 59 && back.second < 60)

		// On a day ending in a leap second, the same holds just before 23:59:61.
		let leapDay = try UTCDay(julianDayNumber: civilDay(2016, 12, 31))
		let leap = try leapDay.timeOfDay(leapDay.julianDate(TimeOfDay(hour: 23, minute: 59, second: Double(61).nextDown)))
		#expect(leap.hour == 23 && leap.minute == 59 && leap.second >= 60 && leap.second < 61)
	}

	@Test func shortenedDay() throws {
		// 1961-07-31 ended 0.05 s early, so its clock stopped at 23:59:59.95.
		let day = try UTCDay(julianDayNumber: civilDay(1961, 7, 31))
		#expect(throws: Never.self) { try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: 59.9)) }
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: 59.95))
		}
		// The last reading before the end of the day is valid.
		let last = try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: Double(59.95).nextDown))
		#expect(last.julianDayNumber == day.julianDayNumber)
	}

	@Test func lengthenedDayEnd() throws {
		// 1965-02-28 ended with a step of 0.1 s, so its clock read up to, but not including,
		// 23:59:60.1.
		let day = try UTCDay(julianDayNumber: civilDay(1965, 2, 28))
		#expect(day.offsetStep == 0.1)
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: 60.1))
		}
		let last = try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: Double(60.1).nextDown))
		#expect(last.julianDayNumber == day.julianDayNumber)
		let back = try day.timeOfDay(last)
		#expect(back.hour == 23 && back.minute == 59 && back.second < 60.1)
	}

	@Test func stepBefore1972() throws {
		// 1971-12-31 ended with a step of 0.107758 s, so its clock read up to 23:59:60.107758.
		let day = try UTCDay(julianDayNumber: civilDay(1971, 12, 31))
		let time = try TimeOfDay(hour: 23, minute: 59, second: 60.1)
		let back = try day.timeOfDay(day.julianDate(time))
		#expect(back.hour == 23 && back.minute == 59)
		#expect(abs(back.second - 60.1) <= timescaleTolerance)
		#expect(throws: TimescaleConversionError.invalidTimeOfDay) {
			try day.julianDate(TimeOfDay(hour: 23, minute: 59, second: 60.2))
		}
	}
}
