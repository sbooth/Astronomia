//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LunarApsidesTests {
	typealias Expected = (whole: Double, fraction: Double, kind: Moon.ApsisEvent.Kind, distance: Double)

	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the difference from a Skyfield apsis, in seconds.
	static func difference(_ instant: Instant<TT>, _ expected: Expected) -> Double {
		abs((julianDate(instant) - expected.whole) - expected.fraction) * secondsPerDay
	}

	static func instant(_ julianDate: Double) throws -> Instant<TT> {
		Instant(try JulianDate(julianDate: julianDate))
	}

	static func seconds(from a: Instant<TT>, to b: Instant<TT>) -> Double {
		(julianDate(b) - julianDate(a)) * secondsPerDay
	}

	@Test func matchesSkyfield() throws {
		// A year at full precision, within 0.5 s and 10 m of Skyfield's with DE421
		let (from, to) = (2_461_041.5, 2_461_406.5)
		let events = try Moon.apsides(from: Self.instant(from), to: Self.instant(to))
		let expected = skyfieldLunarApsides.filter { $0.whole + $0.fraction > from && $0.whole + $0.fraction < to }
		#expect(events.count == expected.count && expected.count > 25)
		for (event, expected) in zip(events, expected) {
			#expect(event.kind == expected.kind)
			#expect(Self.difference(event.instant, expected) <= 0.5, "\(event.kind) \(expected)")
			#expect(abs(event.distance.kilometers - expected.distance) <= 0.01)
		}
		// The rest of the span, one every few months, within 0.5 s and 10 m
		for (index, expected) in skyfieldLunarApsides.enumerated() where index % 50 == 17 {
			let event = try Moon.nextApsis(expected.kind, after: Self.instant(expected.whole + expected.fraction - 3))
			#expect(Self.difference(event.instant, expected) <= 0.5, "\(expected)")
			#expect(abs(event.distance.kilometers - expected.distance) <= 0.01)
		}
	}

	@Test func distanceIsLeastOrGreatest() throws {
		// A minute either side of each, the Moon is a little farther at perigee, and nearer at
		// apogee.
		let ephemeris = BuiltInEphemeris()
		let events = try Moon.apsides(from: Self.instant(2_461_041.5), to: Self.instant(2_461_071.5))
		#expect(events.count >= 2)
		for event in events {
			let sign = event.kind == .perigee ? 1.0 : -1.0
			for offset in [-60.0, 60] {
				let instant = Instant<TT>(try event.instant.julianDate.adding(seconds: offset))
				let distance = try ephemeris.state(of: .moon, relativeTo: .earth, at: instant).position.distance.kilometers
				#expect(sign * (distance - event.distance.kilometers) > 0)
			}
		}
	}

	@Test func alternate() throws {
		// Over several years perigees and apogees alternate, 11 to 17 days apart, at the
		// distances they reach.
		let events = try Moon.apsides(from: Self.instant(2_451_544.5), to: Self.instant(2_453_371.5))
		#expect(events.count > 130)
		for (a, b) in zip(events, events.dropFirst()) {
			#expect(a.kind != b.kind)
			let days = (Self.julianDate(b.instant) - Self.julianDate(a.instant))
			#expect(days > 11 && days < 17)
		}
		for event in events {
			let kilometers = event.distance.kilometers
			#expect(event.kind == .perigee ? (kilometers > 356_000 && kilometers < 371_000) : (kilometers > 404_000 && kilometers < 407_000))
		}
	}

	@Test func next() throws {
		let events = try Moon.apsides(from: Self.instant(2_461_041.5), to: Self.instant(2_461_100.5))
		for event in events.prefix(3) {
			// From a day or two seconds before, that one
			for before in [86_400.0, 2] {
				let found = try Moon.nextApsis(event.kind, after: Instant<TT>(try event.instant.julianDate.adding(seconds: -before)))
				#expect(found.kind == event.kind)
				#expect(abs(Self.seconds(from: event.instant, to: found.instant)) < 0.1)
			}
			// From itself, the next of its kind, 24 to 29 days later
			let later = try Moon.nextApsis(event.kind, after: event.instant)
			let days = Self.seconds(from: event.instant, to: later.instant) / secondsPerDay
			#expect(days > 24 && days < 29, "\(event.kind): \(days)")
		}
		// In UTC
		let utc = try Instant<TT>(try events[0].instant.julianDate.adding(days: -0.25)).converted(to: UTC.self)
		let found = try Moon.nextApsis(events[0].kind, after: utc)
		#expect(abs(Self.seconds(from: events[0].instant, to: found.instant)) < 0.1)
	}

	@Test func intervals() throws {
		let start = try Self.instant(2_461_041.5)
		#expect(try Moon.apsides(from: start, to: start).isEmpty)
		#expect(throws: Moon.ApsisError.invalidInterval) {
			try Moon.apsides(from: start, to: Self.instant(2_461_041.4))
		}
		// An interval around one finds it, even two seconds from an end, and one just before or
		// after doesn't.
		let perigee = try Moon.nextApsis(.perigee, after: start)
		for (before, after) in [(60.0, 60.0), (2, 30_000), (30_000, 2), (2, 3)] {
			let from = Instant<TT>(try perigee.instant.julianDate.adding(seconds: -before))
			let to = Instant<TT>(try perigee.instant.julianDate.adding(seconds: after))
			let events = try Moon.apsides(from: from, to: to)
			#expect(events.map(\.kind) == [.perigee], "\(before) \(after)")
		}
		let justBefore = Instant<TT>(try perigee.instant.julianDate.adding(seconds: -60))
		let justAfter = Instant<TT>(try perigee.instant.julianDate.adding(seconds: 60))
		#expect(try Moon.apsides(from: Instant<TT>(try justBefore.julianDate.adding(days: -5)), to: justBefore).isEmpty)
		#expect(try Moon.apsides(from: justAfter, to: Instant<TT>(try justAfter.julianDate.adding(days: 5))).isEmpty)
		#expect(throws: Moon.ApsisError.ephemeris(.outsideCoverage)) {
			try Moon.apsides(from: Instant<TT>(try JulianDate(year: 900, month: 1, day: 1)), to: Instant<TT>(try JulianDate(year: 900, month: 2, day: 1)))
		}
	}

	@Test func apsisAtTheEndOfTheCoverage() throws {
		// One 15 minutes before the end of the coverage is found, and one past it isn't.
		let start = try Self.instant(2_461_041.5)
		let apogee = try Moon.nextApsis(.apogee, after: start)
		let ephemeris = try TruncatedEphemeris(BuiltInEphemeris(), endingAt: Instant(try apogee.instant.julianDate.adding(seconds: 900)))
		let found = try Moon.nextApsis(.apogee, of: .moon, after: start, ephemeris: ephemeris)
		#expect(abs(Self.seconds(from: apogee.instant, to: found.instant)) < 0.1)
		#expect(throws: Moon.ApsisError.ephemeris(.outsideCoverage)) {
			try Moon.nextApsis(.perigee, of: .moon, after: apogee.instant, ephemeris: ephemeris)
		}
	}
}

/// An ephemeris whose Moon is at a non-finite position.
struct NonFiniteMoonEphemeris: GeocentricEphemeris {
	typealias Body = BuiltInEphemeris.Body
	typealias Frame = BuiltInEphemeris.Frame

	static var defaultOrigin: Body { BuiltInEphemeris.defaultOrigin }
	static var earth: Body { BuiltInEphemeris.earth }
	static var sun: Body { BuiltInEphemeris.sun }
	static var solarSystemBarycenter: Body { BuiltInEphemeris.solarSystemBarycenter }
	static var lightDeflectingBodies: [LightDeflectingBody<Body>] { BuiltInEphemeris.lightDeflectingBodies }

	let base = BuiltInEphemeris()
	/// The value of each coordinate of the Moon's position.
	let value: Double

	var coverage: ClosedRange<Instant<TDB>> { base.coverage }

	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Frame> {
		guard body == .moon else { return try base.state(of: body, relativeTo: origin, at: tdb) }
		return StateVector(Vector3(value, value, value), .zero)
	}
}

extension LunarApsidesTests {
	@Test func nonFiniteDistances() throws {
		// A Moon at NaN or infinity throws, rather than finding no apsis.
		let start = try Self.instant(2_461_041.5)
		for value in [Double.nan, .infinity] {
			let ephemeris = NonFiniteMoonEphemeris(value: value)
			#expect(throws: Moon.ApsisError.ephemeris(.invalidState)) {
				try Moon.apsides(of: .moon, from: start, to: Self.instant(2_461_071.5), ephemeris: ephemeris)
			}
			#expect(throws: Moon.ApsisError.ephemeris(.invalidState)) {
				try Moon.nextApsis(.perigee, of: .moon, after: start, ephemeris: ephemeris)
			}
		}
	}
}

@Suite struct SemidiameterTests {
	@Test func moonAndSun() throws {
		// From the center of the Earth at a perigee, the Moon's semidiameter is asin(R / d), and
		// the Sun's about 16'.
		let perigee = try Moon.nextApsis(.perigee, after: Instant<TT>(try JulianDate(julianDate: 2_461_041.5)))
		let sky = try Observer.geocenter.observation(at: perigee.instant, ephemeris: BuiltInEphemeris())
		let moon = try #require(try sky.semidiameter(of: .moon))
		#expect(moon.arcminutes > 16 && moon.arcminutes < 17)
		let distance = try sky.apparentPlace(of: .moon).position.distance
		#expect(abs(moon.radians - Math.asin(1_737.4 / distance.kilometers)) < 1e-15)
		let sun = try #require(try sky.semidiameter(of: .sun))
		#expect(sun.arcminutes > 15.7 && sun.arcminutes < 16.3)
		// A barycenter has no radius.
		#expect(try sky.semidiameter(of: .solarSystemBarycenter) == nil)
	}

	@Test func moonIsLargerFromASiteWhereItIsHigh() throws {
		// From a site with the Moon near the zenith it is nearer by about the Earth's radius,
		// so larger by about 1.7%, and near the horizon about the same as from the center.
		let instant = try Moon.nextApsis(.perigee, after: Instant<TT>(try JulianDate(julianDate: 2_461_041.5))).instant
		let geocentric = try #require(try Observer.geocenter.observation(at: instant, ephemeris: BuiltInEphemeris()).semidiameter(of: .moon))
		let place = try Observer.geocenter.observation(at: instant, ephemeris: BuiltInEphemeris()).apparentPlace(of: .moon, in: TrueEquatorOfDate.self).position.spherical
		let earthOrientation = EarthOrientation.model
		let gast = try EarthRotation.greenwichApparentSiderealTime(at: instant, earthOrientation: earthOrientation)
		// The site beneath the Moon: its declination as latitude, its hour angle zero
		let longitude = Angle(radians: place.rightAscension.radians - gast.radians).normalizedSigned()
		let beneath = try Observer.site(latitude: place.declination, longitude: longitude)
		let overhead = try #require(try beneath.observation(at: instant, ephemeris: BuiltInEphemeris()).semidiameter(of: .moon))
		let ratio = overhead.radians / geocentric.radians
		#expect(ratio > 1.015 && ratio < 1.019, "\(ratio)")
	}
}
