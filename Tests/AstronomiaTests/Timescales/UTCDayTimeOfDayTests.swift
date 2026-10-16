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
