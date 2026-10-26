//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LunarNodesTests {
	typealias Expected = (whole: Double, fraction: Double, kind: Moon.NodeEvent.Kind, longitude: Double)

	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the difference from a Skyfield passage, in seconds.
	static func difference(_ instant: Instant<TT>, _ expected: Expected) -> Double {
		abs((julianDate(instant) - expected.whole) - expected.fraction) * secondsPerDay
	}

	/// Returns the difference of two longitudes, in radians, reduced to [-π, π].
	static func difference(_ a: Double, _ b: Double) -> Double {
		abs((a - b).remainder(dividingBy: twoPi))
	}

	static func instant(_ julianDate: Double) throws -> Instant<TT> {
		Instant(try JulianDate(julianDate: julianDate))
	}

	static func seconds(from a: Instant<TT>, to b: Instant<TT>) -> Double {
		(julianDate(b) - julianDate(a)) * secondsPerDay
	}

	@Test func matchesSkyfield() throws {
		// A year at full precision, within 0.25 s and 0.1" of Skyfield's with DE421
		let (from, to) = (2_461_041.5, 2_461_406.5)
		let events = try Moon.nodes(from: Self.instant(from), to: Self.instant(to))
		let expected = skyfieldLunarNodes.filter { $0.whole + $0.fraction > from && $0.whole + $0.fraction < to }
		#expect(events.count == expected.count && expected.count > 25)
		for (event, expected) in zip(events, expected) {
			#expect(event.kind == expected.kind)
			#expect(Self.difference(event.instant, expected) <= 0.25, "\(event.kind) \(expected)")
			#expect(Self.difference(event.longitude.radians, expected.longitude) <= Angle(arcseconds: 0.1).radians)
		}
		// The rest of the span, one every few months, at 1", within 9 s and 6"
		for (index, expected) in skyfieldLunarNodes.enumerated() where index % 50 == 17 {
			let event = try Moon.nextNode(expected.kind, after: Self.instant(expected.whole + expected.fraction - 3), precision: .arcsecond)
			#expect(Self.difference(event.instant, expected) <= 9, "\(expected)")
			#expect(Self.difference(event.longitude.radians, expected.longitude) <= Angle(arcseconds: 6).radians)
		}
	}

	@Test func latitudeCrossesZero() throws {
		// A minute before each passage the Moon is on the other side of the ecliptic, and a
		// minute after on the side it crosses to.
		let ephemeris = BuiltInEphemeris(precision: .tenthArcsecond)
		let events = try Moon.nodes(from: Self.instant(2_461_041.5), to: Self.instant(2_461_071.5), precision: .tenthArcsecond)
		#expect(events.count >= 2)
		for event in events {
			let sign = event.kind == .ascending ? 1.0 : -1.0
			for offset in [-60.0, 60] {
				let instant = Instant<TT>(try event.instant.julianDate.adding(seconds: offset))
				let latitude = try Observer.geocenter.observation(at: instant, ephemeris: ephemeris).apparentPlace(of: .moon, in: TrueEclipticOfDate.self).position.spherical.latitude.radians
				#expect(sign * offset * latitude > 0)
			}
		}
	}

	@Test func nodesRegress() throws {
		// Over the 18.6-year cycle the passages alternate, 12 to 15 days apart, and the
		// ascending node's longitude falls by about 1.4° a month, around the ecliptic once.
		let events = try Moon.nodes(from: Self.instant(2_451_544.5), to: Self.instant(2_458_340.5), precision: .arcsecond)
		#expect(events.count > 490)
		for (a, b) in zip(events, events.dropFirst()) {
			#expect(a.kind != b.kind)
			let days = Self.julianDate(b.instant) - Self.julianDate(a.instant)
			#expect(days > 12 && days < 15)
		}
		let ascending = events.filter { $0.kind == .ascending }
		var total = 0.0
		for (a, b) in zip(ascending, ascending.dropFirst()) {
			let change = (b.longitude.radians - a.longitude.radians).remainder(dividingBy: twoPi)
			// The Moon's longitude at a node wanders with the perturbations, but on average falls.
			#expect(abs(change) < Angle(degrees: 20).radians)
			total += change
		}
		#expect(abs(Angle(radians: total).degrees + 360) < 10)
	}

	@Test func next() throws {
		let events = try Moon.nodes(from: Self.instant(2_461_041.5), to: Self.instant(2_461_100.5), precision: .arcsecond)
		for event in events.prefix(3) {
			// From a day or two seconds before, that one
			for before in [86_400.0, 2] {
				let found = try Moon.nextNode(event.kind, after: Instant<TT>(try event.instant.julianDate.adding(seconds: -before)), precision: .arcsecond)
				#expect(found.kind == event.kind)
				#expect(abs(Self.seconds(from: event.instant, to: found.instant)) < 0.1)
			}
			// From itself, the next of its kind, a draconic month later
			let later = try Moon.nextNode(event.kind, after: event.instant, precision: .arcsecond)
			let days = Self.seconds(from: event.instant, to: later.instant) / secondsPerDay
			#expect(days > 26.9 && days < 27.6, "\(event.kind): \(days)")
		}
		// In UTC
		let utc = try Instant<TT>(try events[0].instant.julianDate.adding(days: -0.25)).converted(to: UTC.self)
		let found = try Moon.nextNode(events[0].kind, after: utc, precision: .arcsecond)
		#expect(abs(Self.seconds(from: events[0].instant, to: found.instant)) < 0.1)
	}

	@Test func intervals() throws {
		let start = try Self.instant(2_461_041.5)
		#expect(try Moon.nodes(from: start, to: start, precision: .arcsecond).isEmpty)
		#expect(throws: Moon.NodeError.invalidInterval) {
			try Moon.nodes(from: start, to: Self.instant(2_461_041.4))
		}
		// An interval around one finds it, even two seconds from an end, and one just before or
		// after doesn't.
		let ascending = try Moon.nextNode(.ascending, after: start, precision: .arcsecond)
		for (before, after) in [(60.0, 60.0), (2, 30_000), (30_000, 2), (2, 3)] {
			let from = Instant<TT>(try ascending.instant.julianDate.adding(seconds: -before))
			let to = Instant<TT>(try ascending.instant.julianDate.adding(seconds: after))
			#expect(try Moon.nodes(from: from, to: to, precision: .arcsecond).map(\.kind) == [.ascending], "\(before) \(after)")
		}
		let justBefore = Instant<TT>(try ascending.instant.julianDate.adding(seconds: -60))
		let justAfter = Instant<TT>(try ascending.instant.julianDate.adding(seconds: 60))
		#expect(try Moon.nodes(from: Instant<TT>(try justBefore.julianDate.adding(days: -5)), to: justBefore, precision: .arcsecond).isEmpty)
		#expect(try Moon.nodes(from: justAfter, to: Instant<TT>(try justAfter.julianDate.adding(days: 5)), precision: .arcsecond).isEmpty)
		#expect(throws: Moon.NodeError.ephemeris(.outsideCoverage)) {
			try Moon.nodes(from: Instant<TT>(try JulianDate(year: 900, month: 1, day: 1)), to: Instant<TT>(try JulianDate(year: 900, month: 2, day: 1)), precision: .arcsecond)
		}
	}

	@Test func passageAtTheEndOfTheCoverage() throws {
		// One 15 minutes before the end of the coverage is found, and one past it isn't.
		let start = try Self.instant(2_461_041.5)
		let descending = try Moon.nextNode(.descending, after: start, precision: .arcsecond)
		let ephemeris = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try descending.instant.julianDate.adding(seconds: 900)))
		let found = try Moon.nextNode(.descending, of: .moon, after: start, ephemeris: ephemeris)
		#expect(abs(Self.seconds(from: descending.instant, to: found.instant)) < 0.1)
		#expect(throws: Moon.NodeError.ephemeris(.outsideCoverage)) {
			try Moon.nextNode(.ascending, of: .moon, after: descending.instant, ephemeris: ephemeris)
		}
	}
}

@Suite struct CrossingSearchTests {
	/// A sinusoid with a period of 27.2 days, rising through zero at multiples of the period
	/// and falling through it half a period later.
	static func sinusoid(_ days: Double) -> Double {
		0.09 * Math.sin(twoPi * days / 27.2)
	}

	@Test func findsAlternatingCrossings() {
		let search = CrossingSearch<Never>(length: 60, step: 1, skip: 10) { Self.sinusoid($0 + 1) }
		let crossings = search.crossings()
		#expect(crossings.map(\.isRising) == [false, true, false, true])
		for (index, crossing) in crossings.enumerated() {
			#expect(abs(crossing.time - (13.6 * Double(index + 1) - 1)) * secondsPerDay < 0.1)
		}
		#expect(search.crossings(only: true).map(\.isRising) == [true, true])
		#expect(search.crossings(stoppingAfterFirst: true).count == 1)
	}

	@Test func crossingsNearTheEnds() {
		// Half a second after the start or before the end is found, and half a second outside
		// isn't.
		let seconds = 1 / secondsPerDay
		for (start, length) in [(13.6 - 0.5 * seconds, 1.0), (13.0, 0.6 + 0.5 * seconds)] {
			let search = CrossingSearch<Never>(length: length, step: 1, skip: 10) { Self.sinusoid(start + $0) }
			let crossings = search.crossings()
			#expect(crossings.count == 1, "\(start) \(length)")
			#expect(abs(start + (crossings.first?.time ?? 0) - 13.6) * secondsPerDay < 0.1)
		}
		for (start, length) in [(13.6 + 0.5 * seconds, 1.0), (13.0, 0.6 - 0.5 * seconds)] {
			#expect(CrossingSearch<Never>(length: length, step: 1, skip: 10) { Self.sinusoid(start + $0) }.crossings().isEmpty)
		}
	}

	@Test func crossingsExactlyAtTheEnds() {
		// The interval is closed: a quantity zero at the start or the end crosses there, rising
		// or falling.
		for step in [1.0, 0.25] {
			for (function, isRising, time) in [({ (t: Double) in t - 1 }, true, 1.0), ({ 1 - $0 }, false, 1), ({ $0 }, true, 0), ({ -$0 }, false, 0)] {
				let crossings = CrossingSearch<Never>(length: 1, step: step, skip: 10, evaluate: function).crossings()
				#expect(crossings.map(\.isRising) == [isRising], "\(isRising) \(time) \(step)")
				#expect(crossings.first?.time == time)
			}
		}
	}
}
