//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TopocentricTests {
	/// Microarcseconds per radian.
	static let uas = microarcsecondsPerRadian
	/// The Earth orientation of the fixtures: UT1 = TT - 69.2 s, no polar motion or pole offsets.
	static let earthOrientation = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(69.2)))

	static func site(_ index: Int) throws -> Observer {
		let s = fixtureSites[index]
		return try Observer.site(latitude: .degrees(s.latitude), longitude: .degrees(s.longitude), height: .meters(s.height), ellipsoid: s.ellipsoid)
	}

	static func vector(_ v: [Double]) -> Vector3 {
		Vector3(v[0], v[1], v[2])
	}

	static func unit(_ v: Vector3) -> Vector3 {
		v / v.length
	}

	/// Returns the angle between two vectors, in µas.
	static func separation(_ a: Vector3, _ b: Vector3) -> Double {
		Math.atan2(a.cross(b).length, a.dot(b)) * uas
	}

	/// Returns an observation from a fixture site at a TT Julian Date.
	static func observation(site: Int, julianDate: Double) throws -> Observation<BuiltInEphemeris> {
		try Self.site(site).observation(at: Instant<TT>(try JulianDate(julianDate: julianDate)), earthOrientation: Self.earthOrientation)
	}

	@Test func geodeticMatchesERFA() throws {
		for row in erfaSiteGeodetic {
			let site = fixtureSites[row.site]
			let position = try #require(try Self.site(row.site).position).vector * metersPerAstronomicalUnit
			#expect((position - Self.vector(row.position)).length <= 1e-6)
			let geodetic = site.ellipsoid.geodetic(Self.vector(row.position) / metersPerAstronomicalUnit)
			#expect(abs(geodetic.latitude - row.latitude) <= 1e-14)
			#expect(abs(geodetic.longitude - row.longitude) <= 1e-14)
			#expect(abs(geodetic.height * metersPerAstronomicalUnit - row.height) <= 1e-6)
		}
	}

	@Test func sites() throws {
		#expect(Observer.geocenter.position == nil)
		let greenwich = try Self.site(0)
		#expect(try Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005), height: .meters(46)) == greenwich)
		// A site from its ITRS position is at the same place, with its geodetic coordinates
		// recovered to rounding.
		let position = try #require(greenwich.position)
		let recovered = try Observer.site(position)
		#expect(recovered.position == position)
		guard case let .site(_, latitude, longitude) = recovered.location else { Issue.record(); return }
		#expect(abs(latitude - Angle(degrees: 51.4769).radians) <= 1e-15)
		#expect(abs(longitude - Angle(degrees: -0.0005).radians) <= 1e-15)
		// The ellipsoids differ by about 0.1 mm.
		let grs80 = try #require(try Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005), height: .meters(46), ellipsoid: .grs80).position)
		let difference = (grs80.vector - position.vector).length * metersPerAstronomicalUnit
		#expect(difference > 0 && difference < 1e-3)
		_ = try Observer.site(latitude: .degrees(-90), longitude: .degrees(400), height: .kilometers(-100))
		_ = try Observer.site(latitude: .degrees(90), longitude: .zero, height: .kilometers(100))
	}

	@Test func sitesAtTheHeightLimits() throws {
		// A site created at either limit survives the round trip through its ITRS position,
		// though the recovered height rounds past the limit.
		for latitude in [0.0, 45, 90] {
			for height in [Distance.kilometers(100), .kilometers(-100)] {
				let site = try Observer.site(latitude: .degrees(latitude), longitude: .degrees(30), height: height)
				let position = try #require(site.position)
				#expect(try Observer.site(position).position == position, "\(latitude)° \(height)")
			}
		}
		// Beyond the allowance, it is still rejected.
		let position = try #require(try Observer.site(latitude: .zero, longitude: .zero, height: .kilometers(100)).position)
		#expect(throws: ObserverError.invalidHeight) { try Observer.site(Position<ITRS>(x: position.x + .meters(0.001), y: .zero, z: .zero)) }
	}

	@Test func siteValidation() {
		#expect(throws: ObserverError.nonFiniteValue) { try Observer.site(latitude: .degrees(.nan), longitude: .zero) }
		#expect(throws: ObserverError.nonFiniteValue) { try Observer.site(latitude: .zero, longitude: .degrees(.infinity)) }
		#expect(throws: ObserverError.nonFiniteValue) { try Observer.site(latitude: .zero, longitude: .zero, height: .meters(.nan)) }
		#expect(throws: ObserverError.invalidLatitude) { try Observer.site(latitude: .degrees(90.000_001), longitude: .zero) }
		#expect(throws: ObserverError.invalidLatitude) { try Observer.site(latitude: .degrees(-90.000_001), longitude: .zero) }
		#expect(throws: ObserverError.invalidHeight) { try Observer.site(latitude: .zero, longitude: .zero, height: .kilometers(100.001)) }
		#expect(throws: ObserverError.invalidHeight) { try Observer.site(latitude: .zero, longitude: .zero, height: .kilometers(-100.001)) }
		// A position far from the ellipsoid, or not finite
		#expect(throws: ObserverError.invalidHeight) { try Observer.site(Position<ITRS>(x: .kilometers(6_500), y: .zero, z: .zero)) }
		#expect(throws: ObserverError.invalidHeight) { try Observer.site(Position<ITRS>(x: .zero, y: .zero, z: .zero)) }
		#expect(throws: ObserverError.nonFiniteValue) { try Observer.site(Position<ITRS>(x: .kilometers(.nan), y: .zero, z: .zero)) }
	}

	@Test func siteStatesMatchERFA() throws {
		for row in erfaSiteStates {
			let observation = try Self.observation(site: row.site, julianDate: row.julianDate)
			let earth = try observation.positions.state(of: .earth)
			let position = (observation.observerVectors.position - earth.position) * metersPerAstronomicalUnit
			let velocity = (observation.observerVectors.velocity - earth.velocity) * (metersPerAstronomicalUnit / secondsPerDay)
			#expect((position - Self.vector(row.position)).length <= 1e-3)
			#expect((velocity - Self.vector(row.velocity)).length <= 1e-6)
		}
	}

	@Test func starPlacesMatchERFA() throws {
		var observations: [String: Observation<BuiltInEphemeris>] = [:]
		for row in erfaTopocentricStarPlaces {
			let key = "\(row.site) \(row.julianDate)"
			let observation = try observations[key] ?? Self.observation(site: row.site, julianDate: row.julianDate)
			observations[key] = observation
			let star = try StarTests.star(row.star)
			#expect(Self.separation(try observation.astrometricPlace(of: star).position.vector, Self.vector(row.astrometric)) <= 0.02)
			#expect(Self.separation(try observation.apparentPlace(of: star).position.vector, Self.vector(row.apparent)) <= 0.3)
		}
	}

	@Test func bodyShiftsMatchSkyfield() throws {
		// The shift from the geocentric place to the place seen from the site, compared with
		// Skyfield's, allowing for the ephemerides' differing distances and directions, which
		// scale the parallax. Below the horizon, where light would pass through the Earth,
		// Skyfield deflects it and Astronomia doesn't.
		var compared = 0
		var observations: [String: Observation<BuiltInEphemeris>] = [:]
		for row in skyfieldTopocentricPlaces {
			let tt = Instant<TT>(try JulianDate(julianDate: row.julianDate))
			let key = "\(row.site) \(row.julianDate)"
			let observation = try observations[key] ?? Self.observation(site: row.site, julianDate: row.julianDate)
			observations[key] = observation
			let geocentricObservation = try observations["\(row.julianDate)"] ?? Observer.geocenter.observation(at: tt)
			observations["\(row.julianDate)"] = geocentricObservation
			let topocentric = try observation.apparentPlace(of: row.body).position.vector
			let geocentric = try geocentricObservation.apparentPlace(of: row.body).position.vector
			let up = observation.observerVectors.position - (try observation.positions.state(of: .earth)).position
			guard topocentric.dot(up) >= 0 else { continue }
			let ours = Self.unit(topocentric) - Self.unit(geocentric)
			let theirs = Self.unit(Self.vector(row.topocentric)) - Self.unit(Self.vector(row.geocentric))
			let reference = Self.vector(row.geocentric)
			let allowance = theirs.length * Self.uas * abs(geocentric.length / reference.length - 1) + up.length / reference.length * Self.separation(geocentric, reference)
			#expect((ours - theirs).length * Self.uas <= allowance + 0.1, "\(row.body) from \(fixtureSites[row.site].name) at \(row.julianDate)")
			compared += 1
		}
		#expect(compared > skyfieldTopocentricPlaces.count / 3)
	}

	@Test func earthDeflection() throws {
		let observation = try Self.observation(site: 0, julianDate: 2_461_334.75)
		let noEarth = try Self.site(0).observation(at: observation.instant, earthOrientation: Self.earthOrientation, ephemeris: NoEarthDeflectionEphemeris())
		let up = observation.observerVectors.position - (try observation.positions.state(of: .earth)).position
		var largest = 0.0
		for index in fixtureStars.indices {
			let star = try StarTests.star(index)
			let place = try observation.apparentPlace(of: star).position.vector
			let deflection = Self.separation(place, try noEarth.apparentPlace(of: star).position.vector)
			if place.dot(up) >= 0 {
				// At most 0.57 mas, at the horizon
				#expect(deflection <= 570)
				largest = max(largest, deflection)
			} else {
				#expect(deflection == 0)
			}
		}
		#expect(largest > 0.1)

		// A star at the nadir, where the deflection of light passing through the Earth would
		// be unbounded, is undeflected.
		let down = -up / up.length
		let nadir = try Star(rightAscension: .radians(Math.atan2(down.y, down.x)), declination: .radians(Math.asin(down.z)), epoch: Instant(try JulianDate(julianDate: 2_461_334.75)))
		let place = try observation.apparentPlace(of: nadir).position.vector
		#expect(place.x.isFinite && place.y.isFinite && place.z.isFinite)
		#expect(place == (try noEarth.apparentPlace(of: nadir).position.vector))
	}

	@Test func earthOrientation() throws {
		let tt = Instant<TT>(try JulianDate(julianDate: 2_461_334.75))
		let other = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(70.2)))
		// A geocentric observer doesn't depend on it.
		#expect(try Observer.geocenter.observation(at: tt, earthOrientation: other).apparentPlace(of: .mars) == Observer.geocenter.observation(at: tt).apparentPlace(of: .mars))
		// A second of UT1 turns a site by 15" about the pole, which moves the Moon's place.
		let site = try Self.site(0)
		let a = try site.observation(at: tt, earthOrientation: Self.earthOrientation)
		let b = try site.observation(at: tt, earthOrientation: other)
		#expect(a.earthOrientation.ut1.deltaT.deltaT(atTT: tt.julianDate) == 69.2)
		let shift = Self.separation(try a.apparentPlace(of: .moon).position.vector, try b.apparentPlace(of: .moon).position.vector)
		#expect(shift > 100_000 && shift < 300_000)
		// Without UT1, a site can't be placed, though the geocenter can.
		let noUT1 = EarthOrientation(ut1: UT1.Context(deltaTTable: nil, model: nil))
		#expect(throws: EphemerisError.timescaleConversion(.deltaTUnavailable)) { try site.observation(at: tt, earthOrientation: noUT1) }
		_ = try Observer.geocenter.observation(at: tt, earthOrientation: noUT1)
	}
}
