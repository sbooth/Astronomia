//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LunarGreatestDeclinationsTests {
	typealias Expected = (whole: Double, fraction: Double, kind: Moon.GreatestDeclinationEvent.Kind, size: Double)

	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the difference from a Skyfield greatest declination, in seconds.
	static func difference(_ instant: Instant<TT>, _ expected: Expected) -> Double {
		abs((julianDate(instant) - expected.whole) - expected.fraction) * secondsPerDay
	}

	/// Returns the signed declination of a Skyfield greatest declination, in radians.
	static func declination(_ expected: Expected) -> Double {
		expected.kind == .north ? expected.size : -expected.size
	}

	static func instant(_ julianDate: Double) throws -> Instant<TT> {
		Instant(try JulianDate(julianDate: julianDate))
	}

	@Test func matchesSkyfield() throws {
		// A year at full precision, within 0.25 s and 10 mas of Skyfield's with DE421
		let (from, to) = (2_461_041.5, 2_461_406.5)
		let events = try Moon.greatestDeclinations(from: Self.instant(from), to: Self.instant(to))
		let expected = skyfieldLunarGreatestDeclinations.filter { $0.whole + $0.fraction > from && $0.whole + $0.fraction < to }
		#expect(events.count == expected.count && expected.count > 25)
		for (event, expected) in zip(events, expected) {
			#expect(event.kind == expected.kind)
			#expect(Self.difference(event.instant, expected) <= 0.25, "\(event.kind) \(expected)")
			#expect(abs(event.declination.radians - Self.declination(expected)) <= Angle(arcseconds: 0.01).radians)
		}
		// The rest of the span, one every few months, at 1", within 6 s and 0.5"
		for (index, expected) in skyfieldLunarGreatestDeclinations.enumerated() where index % 50 == 17 {
			let event = try Moon.nextGreatestDeclination(expected.kind, after: Self.instant(expected.whole + expected.fraction - 3), precision: .arcsecond)
			#expect(Self.difference(event.instant, expected) <= 6, "\(expected)")
			#expect(abs(event.declination.radians - Self.declination(expected)) <= Angle(arcseconds: 0.5).radians)
		}
	}

	@Test func declinationIsGreatest() throws {
		// A minute either side of each, the declination is a little less north or south.
		let ephemeris = BuiltInEphemeris(precision: .tenthArcsecond)
		let events = try Moon.greatestDeclinations(from: Self.instant(2_461_041.5), to: Self.instant(2_461_071.5), precision: .tenthArcsecond)
		#expect(events.count >= 2)
		for event in events {
			let sign = event.kind == .north ? 1.0 : -1.0
			for offset in [-60.0, 60] {
				let instant = Instant<TT>(try event.instant.julianDate.adding(seconds: offset))
				let place = try Observer.geocenter.observation(at: instant, ephemeris: ephemeris).apparentPlace(of: .moon, in: TrueEquatorOfDate.self)
				#expect(sign * (event.declination.radians - place.position.spherical.declination.radians) > 0)
			}
		}
	}

	@Test func alternateAcrossTheCycle() throws {
		// Over the 18.6-year cycle the greatest declinations alternate, 12 to 15 days apart, and
		// reach between about 18.1° and 28.7° north or south.
		let events = try Moon.greatestDeclinations(from: Self.instant(2_451_544.5), to: Self.instant(2_458_800.5), precision: .arcsecond)
		#expect(events.count > 520)
		for (a, b) in zip(events, events.dropFirst()) {
			#expect(a.kind != b.kind)
			let days = Self.julianDate(b.instant) - Self.julianDate(a.instant)
			#expect(days > 12 && days < 15)
		}
		for event in events {
			let degrees = event.declination.degrees * (event.kind == .north ? 1 : -1)
			#expect(degrees > 18 && degrees < 29)
		}
		#expect(events.map { abs($0.declination.degrees) }.max()! > 28.5)
		#expect(events.map { abs($0.declination.degrees) }.min()! < 18.3)
	}

	@Test func next() throws {
		let events = try Moon.greatestDeclinations(from: Self.instant(2_461_041.5), to: Self.instant(2_461_100.5), precision: .arcsecond)
		for event in events.prefix(3) {
			// From two seconds before, that one, not the next
			let justBefore = Instant<TT>(try event.instant.julianDate.adding(seconds: -2))
			let soon = try Moon.nextGreatestDeclination(event.kind, after: justBefore, precision: .arcsecond)
			#expect(abs(Self.julianDate(soon.instant) - Self.julianDate(event.instant)) * secondsPerDay < 0.1)
			// From a day before, that one
			let before = Instant<TT>(try event.instant.julianDate.adding(days: -1))
			let found = try Moon.nextGreatestDeclination(event.kind, after: before, precision: .arcsecond)
			#expect(abs(Self.julianDate(found.instant) - Self.julianDate(event.instant)) * secondsPerDay < 0.1)
			#expect(found.kind == event.kind)
			// From itself, the next of its kind, a tropical month later
			let later = try Moon.nextGreatestDeclination(event.kind, after: event.instant, precision: .arcsecond)
			let days = Self.julianDate(later.instant) - Self.julianDate(event.instant)
			#expect(days > 27.1 && days < 27.7, "\(event.kind): \(days)")
		}
		// In UTC
		let utc = try Instant<TT>(try events[0].instant.julianDate.adding(days: -0.25)).converted(to: UTC.self)
		let found = try Moon.nextGreatestDeclination(events[0].kind, after: utc, precision: .arcsecond)
		#expect(abs(Self.julianDate(found.instant) - Self.julianDate(events[0].instant)) * secondsPerDay < 0.1)
	}

	@Test func intervals() throws {
		let start = try Self.instant(2_461_041.5)
		// An empty interval, and one that ends before it starts
		#expect(try Moon.greatestDeclinations(from: start, to: start, precision: .arcsecond).isEmpty)
		#expect(throws: Moon.GreatestDeclinationError.invalidInterval) {
			try Moon.greatestDeclinations(from: start, to: Self.instant(2_461_041.4))
		}
		// An interval just around one finds it, and one just before or after doesn't.
		let event = try Moon.nextGreatestDeclination(.north, after: start, precision: .arcsecond)
		for (before, after) in [(60.0, 60.0), (10, 30_000), (30_000, 10), (2, 30_000), (30_000, 2), (2, 3)] {
			let from = Instant<TT>(try event.instant.julianDate.adding(seconds: -before))
			let to = Instant<TT>(try event.instant.julianDate.adding(seconds: after))
			let events = try Moon.greatestDeclinations(from: from, to: to, precision: .arcsecond)
			#expect(events.map(\.kind) == [.north], "\(before) \(after)")
			#expect(abs(Self.julianDate(try #require(events.first).instant) - Self.julianDate(event.instant)) * secondsPerDay < 0.1)
		}
		let justBefore = Instant<TT>(try event.instant.julianDate.adding(seconds: -60))
		let justAfter = Instant<TT>(try event.instant.julianDate.adding(seconds: 60))
		#expect(try Moon.greatestDeclinations(from: Instant<TT>(try justBefore.julianDate.adding(days: -5)), to: justBefore, precision: .arcsecond).isEmpty)
		#expect(try Moon.greatestDeclinations(from: justAfter, to: Instant<TT>(try justAfter.julianDate.adding(days: 5)), precision: .arcsecond).isEmpty)
		// Before the coverage
		#expect(throws: Moon.GreatestDeclinationError.ephemeris(.outsideCoverage)) {
			try Moon.greatestDeclinations(from: Instant<TT>(try JulianDate(year: 900, month: 1, day: 1)), to: Instant<TT>(try JulianDate(year: 900, month: 2, day: 1)), precision: .arcsecond)
		}
	}

	@Test func greatestDeclinationAtTheEndOfTheCoverage() throws {
		// One 15 minutes before the end of the coverage is found, though the step after it
		// runs past the end.
		let start = try Self.instant(2_461_041.5)
		let north = try Moon.nextGreatestDeclination(.north, after: start, precision: .arcsecond)
		let ephemeris = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try north.instant.julianDate.adding(seconds: 900)))
		let found = try Moon.nextGreatestDeclination(.north, of: .moon, after: start, ephemeris: ephemeris)
		#expect(abs(Self.julianDate(found.instant) - Self.julianDate(north.instant)) * secondsPerDay < 0.1)
		// One past the end isn't.
		#expect(throws: Moon.GreatestDeclinationError.ephemeris(.outsideCoverage)) {
			try Moon.nextGreatestDeclination(.south, of: .moon, after: north.instant, ephemeris: ephemeris)
		}
	}
}

@Suite struct ExtremumSearchTests {
	/// A sinusoid with a period of 27.3 days and an amplitude of 0.4, whose maxima are at
	/// 6.825 days plus multiples of the period and its minima half a period later.
	static func sinusoid(_ days: Double) -> Double {
		0.4 * Math.sin(twoPi * days / 27.3)
	}

	@Test func findsAlternatingExtremes() {
		let search = ExtremumSearch<Never>(length: 60, step: 1, skip: 10) { Self.sinusoid($0) }
		let extremes = search.extremes()
		#expect(extremes.map(\.isMaximum) == [true, false, true, false])
		for (index, extreme) in extremes.enumerated() {
			let expected = 6.825 + Double(index) * 13.65
			#expect(abs(extreme.time - expected) * secondsPerDay < 0.1)
			#expect(abs(extreme.value - (extreme.isMaximum ? 0.4 : -0.4)) < 1e-12)
		}
		// Only minima, or the first
		#expect(search.extremes(only: false).map(\.isMaximum) == [false, false])
		#expect(search.extremes(stoppingAfterFirst: true).count == 1)
	}

	@Test func roundingErrorsDontMislead() {
		// Noise of 1e-15, far more than the rounding of the quantity, where it changes by less
		// than that over 0.1 s within a minute of an extreme, still leaves each within 0.1 s.
		var state: UInt64 = 1
		let search = ExtremumSearch<Never>(length: 60, step: 1, skip: 10) { days in
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			return Self.sinusoid(days) + Double(Int64(bitPattern: state >> 11) % 1_000) * 1e-18
		}
		for (index, extreme) in search.extremes().enumerated() {
			#expect(abs(extreme.time - (6.825 + Double(index) * 13.65)) * secondsPerDay < 0.1)
		}
	}

	@Test func extremesNearTheEnds() {
		// Within a few seconds of either end, and in intervals shorter than a rise
		let seconds = 1 / secondsPerDay
		for (start, length) in [(6.825 - 2 * seconds, 1.0), (6.825 - 0.5, 0.5 + 2 * seconds), (6.825 - 2 * seconds, 4 * seconds), (6.825 - 0.5 * seconds, seconds)] {
			let search = ExtremumSearch<Never>(length: length, step: 1, skip: 10) { Self.sinusoid(start + $0) }
			let extremes = search.extremes()
			#expect(extremes.count == 1, "\(length)")
			#expect(abs(start + (extremes.first?.time ?? 0) - 6.825) * secondsPerDay < 0.1)
		}
		// But not just outside the interval
		for (start, length) in [(6.825 + 2 * seconds, 1.0), (6.825 - 0.5, 0.5 - 2 * seconds), (6.825 + 2 * seconds, 4 * seconds)] {
			#expect(ExtremumSearch<Never>(length: length, step: 1, skip: 10) { Self.sinusoid(start + $0) }.extremes().isEmpty, "\(length)")
		}
	}

	@Test func quantityUnavailableOutsideTheInterval() throws {
		// Where the quantity can't be evaluated before or after the interval, as at the ends of
		// an ephemeris's coverage, an extreme more than 5 seconds from that end is still found,
		// without failing.
		let seconds = 1 / secondsPerDay
		for (start, length) in [(6.825 - 6 * seconds, 1.0), (6.825 - 0.5, 0.5 + 6 * seconds)] {
			let search = ExtremumSearch<Unavailable>(length: length, step: 1, skip: 10) { (days: Double) throws(Unavailable) -> Double in
				guard days >= 0, days <= length else { throw Unavailable() }
				return Self.sinusoid(start + days)
			}
			let extremes = try search.extremes()
			#expect(extremes.count == 1, "\(length)")
			#expect(abs(start + (extremes.first?.time ?? 0) - 6.825) * secondsPerDay < 0.1)
		}
	}

	struct Unavailable: Error {}

	@Test func extremeBeforeTheQuantityFails() throws {
		// The quantity can't be evaluated from 15 minutes after a maximum, but the maximum is
		// found, and the search fails past it.
		let end = 6.825 + 900 / secondsPerDay
		let search = ExtremumSearch<Unavailable>(length: 30, step: 1, skip: 10) { (days: Double) throws(Unavailable) -> Double in
			guard days <= end else { throw Unavailable() }
			return Self.sinusoid(days)
		}
		let first = try search.extremes(stoppingAfterFirst: true)
		#expect(abs((first.first?.time ?? 0) - 6.825) * secondsPerDay < 0.1)
		#expect(throws: Unavailable.self) { try search.extremes() }
	}
}
