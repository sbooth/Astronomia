//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// The built-in ephemeris without the Earth among the light-deflecting bodies.
struct NoEarthDeflectionEphemeris: GeocentricEphemeris {
	typealias Body = SolarSystemEphemeris.Body
	typealias Frame = ICRS

	static let defaultOrigin = Body.solarSystemBarycenter
	static let earth = Body.earth
	static let sun = Body.sun
	static let solarSystemBarycenter = Body.solarSystemBarycenter
	static let lightDeflectingBodies = SolarSystemEphemeris.lightDeflectingBodies.filter { $0.body != .earth }

	let base = SolarSystemEphemeris()

	var coverage: ClosedRange<Instant<TDB>> {
		base.coverage
	}

	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		try base.state(of: body, relativeTo: origin, at: tdb)
	}
}

@Suite struct ObservationTests {
	static let tdb = Instant<TDB>(JulianDate(uncheckedJulianDayNumber: 2_461_335, fractionFromNoon: -0.5))

	static func star(_ index: Int) throws -> Star {
		try StarTests.star(index)
	}

	@Test func bodyPlacesMatchTheObserverMethods() throws {
		let observation = try Observer.geocenter.observation(at: Self.tdb)
		for body in [SolarSystemEphemeris.Body.sun, .moon, .mars, .earth] {
			#expect(try observation.astrometricPlace(of: body) == Observer.geocenter.astrometricPlace(of: body, at: Self.tdb))
			#expect(try observation.apparentPlace(of: body) == Observer.geocenter.apparentPlace(of: body, at: Self.tdb))
		}
	}

	@Test func starPlacesFromOneObservation() throws {
		let observation = try Observer.geocenter.observation(at: Self.tdb)
		let stars = try fixtureStars.indices.map(Self.star)
		let places = try stars.map { try observation.apparentPlace(of: $0) }
		#expect(places.count == stars.count)
		#expect(places.allSatisfy { $0.instant == observation.instant && $0.position.distance.astronomicalUnits > 20_000 })
	}

	@Test func instantAndObserverState() throws {
		let utc = try Instant<UTC>(JulianDate(julianDate: 2_461_335.25))
		let observation = try Observer.geocenter.observation(at: utc)
		#expect(observation.instant == (try utc.converted(to: TT.self)))
		#expect(observation.observer == .geocenter)
		// The Earth's barycentric state, as the ephemeris gives it
		let tdb = try utc.converted(to: TDB.self)
		let earth = try SolarSystemEphemeris().state(of: .earth, relativeTo: .solarSystemBarycenter, at: tdb)
		#expect((observation.observerState.position.vector - earth.position.vector).length <= 1e-15)
		#expect((observation.observerState.velocity.vector - earth.velocity.vector).length <= 1e-17)
		let sendable: any Sendable = observation
		_ = sendable
	}

	@Test func observerMustBeInTheSolarSystem() throws {
		// 20,000 au from the Sun
		#expect(throws: EphemerisError.invalidState) { try Observer.geocenter.observation(at: Self.tdb, ephemeris: AlteredEphemeris(position: SIMD3(20_000, 0, 0))) }
		_ = try Observer.geocenter.observation(at: Self.tdb, ephemeris: AlteredEphemeris(position: SIMD3(9_000, 0, 0)))
	}

	@Test func observerMustBeOutsideTheDeflectors() throws {
		// At Jupiter's center
		let jupiter = try SolarSystemEphemeris().state(of: .jupiterBarycenter, relativeTo: .sun, at: Self.tdb).position.vector
		#expect(throws: EphemerisError.invalidState) {
			try Observer.geocenter.observation(at: Self.tdb, ephemeris: AlteredEphemeris(position: SIMD3(jupiter.x, jupiter.y, jupiter.z)))
		}
		// Just outside the Sun
		let outside = nominalSolarRadius.astronomicalUnits * 1.01
		_ = try Observer.geocenter.observation(at: Self.tdb, ephemeris: AlteredEphemeris(position: SIMD3(outside, 0, 0)))
	}

	@Test func observersOwnBodyDeflectsNothing() throws {
		// A geocentric observer is at the Earth's center, inside its radius, but the Earth
		// deflects nothing it sees.
		#expect(SolarSystemEphemeris.lightDeflectingBodies.contains { $0.body == .earth })
		let withEarth = try Observer.geocenter.observation(at: Self.tdb)
		let withoutEarth = try Observer.geocenter.observation(at: Self.tdb, ephemeris: NoEarthDeflectionEphemeris())
		#expect(try withEarth.apparentPlace(of: .mars) == withoutEarth.apparentPlace(of: .mars))
		let star = try Self.star(2)
		#expect(try withEarth.apparentPlace(of: star) == withoutEarth.apparentPlace(of: star))
	}
}
