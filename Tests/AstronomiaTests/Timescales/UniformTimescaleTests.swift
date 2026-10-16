//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Returns `true` if `scale` conforms to ``UniformTimescale``.
private func isUniform(_ scale: any Timescale.Type) -> Bool {
	scale is any UniformTimescale.Type
}

@Suite struct UniformTimescaleTests {
	@Test func conformances() {
		let uniform: [any Timescale.Type] = [TAI.self, TT.self, TDB.self, TCG.self, TCB.self, GPS.self, Galileo.self, BeiDou.self, QZSS.self, NavIC.self]
		#expect(uniform.allSatisfy(isUniform))
		// Leap seconds, or days that follow Earth's rotation
		#expect(!isUniform(UTC.self))
		#expect(!isUniform(GLONASS.self))
		#expect(!isUniform(UT1.self))
	}

	@Test func arithmetic() throws {
		let start = Instant<TT>(.J2000)
		let later = try start.adding(seconds: 90_000)
		let expected = try JulianDate.J2000.adding(days: 1).adding(seconds: 3_600)
		#expect(try abs(seconds(from: expected, to: later.julianDate)) <= timescaleTolerance)
		#expect(try abs(start.interval(to: later).inSeconds - 90_000) <= timescaleTolerance)
		#expect(try abs(later.interval(to: start).inSeconds + 90_000) <= timescaleTolerance)

		let interval = try DayInterval(days: 1, fractionalDay: 0.25)
		let added = try start.adding(interval)
		#expect(try abs(start.interval(to: added).inDays - 1.25) <= 1e-15)
		#expect(try added.subtracting(interval) == start)
		#expect(try start.interval(to: start) == .zero)
	}

	@Test func elapsedAcrossLeapSecond() throws {
		// 2016-12-31T23:59:59 to 2017-01-01T00:00:01 UTC is three seconds, through 23:59:60.
		let lastDay = try civilDay(2016, 12, 31)
		let before = try Instant<UTC>(utcDate(lastDay, seconds: 86_399)).converted(to: TAI.self)
		let after = try Instant<UTC>(utcDate(lastDay + 1, seconds: 1)).converted(to: TAI.self)
		#expect(try abs(before.interval(to: after).inSeconds - 3) <= timescaleTolerance)

		// A second after 23:59:59 is the leap second, and two seconds after is the next day.
		let leapSecond = try Instant<UTC>(utcDate(lastDay, seconds: 86_400)).converted(to: TAI.self)
		#expect(try abs(before.adding(seconds: 1).interval(to: leapSecond).inSeconds) <= timescaleTolerance)
		let midnight = try Instant<UTC>(utcDate(lastDay + 1)).converted(to: TAI.self)
		#expect(try abs(before.adding(seconds: 2).interval(to: midnight).inSeconds) <= timescaleTolerance)

		// The UTC Julian Dates are not three seconds apart.
		let naive = try Instant<UTC>(utcDate(lastDay, seconds: 86_399)).julianDate
		#expect(try abs(seconds(from: naive, to: utcDate(lastDay + 1, seconds: 1)) - 3) > 1e-6)
	}

	@Test func gnssWeeks() throws {
		// Galileo week 0 starts at GPS week 1024.
		let week1024 = try Instant<GPS>(GPS.epoch).adding(DayInterval(days: 7 * 1024))
		let galileo = try week1024.converted(to: Galileo.self)
		#expect(try abs(Instant<Galileo>(Galileo.epoch).interval(to: galileo).inSeconds) <= timescaleTolerance)
	}

	@Test func intervalsDependOnTimescale() throws {
		// One TT day near J2000.0, measured in TDB and TCB
		let start = Instant<TT>(.J2000)
		let end = try start.adding(DayInterval(days: 1))
		let tdb = try start.converted(to: TDB.self).interval(to: end.converted(to: TDB.self)).inSeconds
		let tcb = try start.converted(to: TCB.self).interval(to: end.converted(to: TCB.self)).inSeconds

		// TDB - TT changes by tens of microseconds a day in January.
		#expect(abs(tdb - 86_400) > 1e-6 && abs(tdb - 86_400) < 1e-4)
		// TCB gains L_B / (1 - L_B) on TDB, about 1.34 ms a day.
		#expect(abs(tcb - tdb - tdb * TCB.rate / (1 - TCB.rate)) <= driftTolerance)
	}
}
