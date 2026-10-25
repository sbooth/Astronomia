//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct MoonPhasesTests {
	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the difference from a Skyfield phase, in seconds.
	static func difference(_ instant: Instant<TT>, _ expected: (whole: Double, fraction: Double, kind: Moon.PhaseEvent.Kind)) -> Double {
		abs((julianDate(instant) - expected.whole) - expected.fraction) * secondsPerDay
	}

	@Test func matchesSkyfield() throws {
		// A year of phases at full precision, within 0.02 s of Skyfield's with DE421
		let (from, to) = (2_461_041.5, 2_461_406.5)
		let start = Instant<TT>(try JulianDate(julianDate: from))
		let end = Instant<TT>(try JulianDate(julianDate: to))
		let events = try Moon.phases(from: start, to: end)
		let expected = skyfieldMoonPhases.filter { $0.whole + $0.fraction > from && $0.whole + $0.fraction < to }
		#expect(events.count == expected.count && expected.count > 48)
		for (event, expected) in zip(events, expected) {
			#expect(event.kind == expected.kind)
			#expect(Self.difference(event.instant, expected) <= 0.05, "\(event.kind) \(expected)")
		}
		// The rest of the span, a phase every few months, at 1", within 1 s
		for (index, expected) in skyfieldMoonPhases.enumerated() where index % 50 == 17 {
			let after = Instant<TT>(try JulianDate(julianDate: expected.whole + expected.fraction - 3))
			let instant = try Moon.nextPhase(expected.kind, after: after, precision: .arcsecond).instant
			#expect(Self.difference(instant, expected) <= 1, "\(expected)")
		}
	}

	@Test func excessEclipticLongitudeAtThePhases() throws {
		// At each phase the Moon's apparent longitude less the Sun's is the phase's, within its
		// motion over 0.1 s, about 0.05"
		let ephemeris = BuiltInEphemeris(precision: .tenthArcsecond)
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		for kind in Moon.PhaseEvent.Kind.allCases {
			let instant = try Moon.nextPhase(kind, after: start, precision: .tenthArcsecond).instant
			let sky = try Observer.geocenter.observation(at: instant, ephemeris: ephemeris)
			let sun = try sky.apparentPlace(of: .sun, in: TrueEclipticOfDate.self).position.spherical.longitude
			let moon = try sky.apparentPlace(of: .moon, in: TrueEclipticOfDate.self).position.spherical.longitude
			let difference = (moon.radians - sun.radians - kind.excessEclipticLongitude.radians).remainder(dividingBy: twoPi)
			#expect(abs(difference) <= Angle(arcseconds: 0.1).radians, "\(kind)")
		}
		#expect(Moon.PhaseEvent.Kind.allCases.map(\.excessEclipticLongitude.degrees) == [0, 90, 180, 270])
	}

	@Test func next() throws {
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		let end = Instant<TT>(try JulianDate(julianDate: 2_461_100.5))
		let events = try Moon.phases(from: start, to: end, precision: .arcsecond)
		for event in events.prefix(4) {
			// From a day before a phase, the phase
			let before = Instant<TT>(try event.instant.julianDate.adding(days: -1))
			let found = try Moon.nextPhase(event.kind, after: before, precision: .arcsecond).instant
			#expect(abs(Self.julianDate(found) - Self.julianDate(event.instant)) * secondsPerDay < 0.1)
			// From the phase itself, the next of its kind, a synodic month later
			let later = try Moon.nextPhase(event.kind, after: event.instant, precision: .arcsecond).instant
			let days = Self.julianDate(later) - Self.julianDate(event.instant)
			#expect(days > 29.2 && days < 29.9, "\(event.kind): \(days)")
		}
		// In UTC
		let utc = try before(events[0].instant).converted(to: UTC.self)
		let found = try Moon.nextPhase(events[0].kind, after: utc, precision: .arcsecond).instant
		#expect(abs(Self.julianDate(found) - Self.julianDate(events[0].instant)) * secondsPerDay < 0.1)
	}

	func before(_ instant: Instant<TT>) throws -> Instant<TT> {
		Instant(try instant.julianDate.adding(days: -0.25))
	}

	@Test func phaseAtTheEndOfTheCoverage() throws {
		// A phase 15 minutes before the end of the coverage is found, though the bracket the
		// search predicts, and a synodic month from the search's start, run past it.
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		let full = try Moon.nextPhase(.fullMoon, after: start, precision: .arcsecond).instant
		let ephemeris = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try full.julianDate.adding(seconds: 900)))
		let found = try Moon.nextPhase(.fullMoon, of: .moon, after: start, ephemeris: ephemeris).instant
		#expect(abs(Self.julianDate(found) - Self.julianDate(full)) * secondsPerDay < 0.1)
		let events = try Moon.phases(of: .moon, from: start, to: Instant<TT>(try full.julianDate.adding(seconds: 600)), ephemeris: ephemeris)
		#expect(events.last?.kind == .fullMoon)
		#expect(abs(Self.julianDate(try #require(events.last).instant) - Self.julianDate(full)) * secondsPerDay < 0.1)
		// A phase past the end isn't.
		#expect(throws: Moon.PhaseError.ephemeris(.outsideCoverage)) { try Moon.nextPhase(.lastQuarter, of: .moon, after: start, ephemeris: ephemeris) }
		// Nor is one past the end of the built-in coverage.
		let last = BuiltInEphemeris().coverage.upperBound.julianDate.daysSinceJ2000 + 2_451_545
		#expect(throws: Moon.PhaseError.ephemeris(.outsideCoverage)) {
			try Moon.phases(from: Instant<TT>(try JulianDate(julianDate: last - 10)), to: Instant<TT>(try JulianDate(julianDate: last + 10)), precision: .arcsecond)
		}
	}

	@Test func phaseNotFound() throws {
		// A Moon that keeps 45° from the Sun never reaches a phase.
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		let ephemeris = CircularEphemeris()
		#expect(try Moon.phases(of: .moon, from: start, to: Instant<TT>(try start.julianDate.adding(days: 60)), ephemeris: ephemeris).isEmpty)
		#expect(throws: Moon.PhaseError.phaseNotFound) { try Moon.nextPhase(.fullMoon, of: .moon, after: start, ephemeris: ephemeris) }
	}

	@Test func intervals() throws {
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		// An empty interval, and one that ends before it starts
		#expect(try Moon.phases(from: start, to: start, precision: .arcsecond).isEmpty)
		#expect(throws: Moon.PhaseError.invalidInterval) { try Moon.phases(from: start, to: Instant<TT>(try JulianDate(julianDate: 2_461_041.4))) }
		// An interval just around one phase finds it, and one just before or after doesn't.
		let full = try Moon.nextPhase(.fullMoon, after: start, precision: .arcsecond).instant
		let before = Instant<TT>(try full.julianDate.adding(seconds: -60))
		let after = Instant<TT>(try full.julianDate.adding(seconds: 60))
		#expect(try Moon.phases(from: before, to: after, precision: .arcsecond).map(\.kind) == [.fullMoon])
		#expect(try Moon.phases(from: Instant<TT>(try before.julianDate.adding(days: -5)), to: before, precision: .arcsecond).isEmpty)
		#expect(try Moon.phases(from: after, to: Instant<TT>(try after.julianDate.adding(days: 5)), precision: .arcsecond).isEmpty)
		// Phases follow in order, about a quarter of a synodic month apart.
		let month = try Moon.phases(from: start, to: Instant<TT>(try start.julianDate.adding(days: 60)), precision: .arcsecond)
		for (a, b) in zip(month, month.dropFirst()) {
			#expect(b.kind.index == (a.kind.index + 1) % 4)
			let days = Self.julianDate(b.instant) - Self.julianDate(a.instant)
			#expect(days > 6 && days < 8.5)
		}
		// Before the coverage
		#expect(throws: Moon.PhaseError.ephemeris(.outsideCoverage)) {
			try Moon.phases(from: Instant<TT>(try JulianDate(year: 900, month: 1, day: 1)), to: Instant<TT>(try JulianDate(year: 900, month: 2, day: 1)), precision: .arcsecond)
		}
	}
}
