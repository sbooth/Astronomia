//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// The built-in ephemeris with the Earth's heliocentric state replaced, as a custom ephemeris
/// might give it.
struct AlteredEarthEphemeris: GeocentricEphemeris {
	typealias Body = SolarSystemEphemeris.Body
	typealias Frame = ICRS

	static let defaultOrigin = Body.solarSystemBarycenter
	static let earth = Body.earth
	static let sun = Body.sun
	static let solarSystemBarycenter = Body.solarSystemBarycenter
	static let lightDeflectingBodies = SolarSystemEphemeris.lightDeflectingBodies

	let base = SolarSystemEphemeris()
	/// The Earth's position relative to the Sun, in au, or `nil` for the built-in one.
	var position: SIMD3<Double>?
	/// The Earth's velocity relative to the Sun, in au/day, or `nil` for the built-in one.
	var velocity: SIMD3<Double>?

	var coverage: ClosedRange<Instant<TDB>> {
		base.coverage
	}

	func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<ICRS> {
		let state = try base.state(of: body, relativeTo: origin, at: tdb)
		guard body == .earth, origin == .sun else {
			return state
		}
		return StateVector(
			position: position.map { Position(x: .astronomicalUnits($0.x), y: .astronomicalUnits($0.y), z: .astronomicalUnits($0.z)) } ?? state.position,
			velocity: velocity.map { Velocity(astronomicalUnitsPerDay: $0) } ?? state.velocity)
	}
}

@Suite struct InvalidStateTests {
	static let tdb = Instant<TDB>(JulianDate(uncheckedJulianDayNumber: 2_461_335, fractionFromNoon: -0.5))
	static let star = try! Star(rightAscension: .degrees(101.287), declination: .degrees(-16.716), parallax: .milliarcseconds(379.21), epoch: tdb)

	/// Expects every place of a body and of a star to throw ``EphemerisError/invalidState``.
	static func expectInvalidState(_ ephemeris: AlteredEarthEphemeris, sourceLocation: SourceLocation = #_sourceLocation) {
		let observer = Observer.geocenter
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try observer.apparentPlace(of: .mars, at: tdb, ephemeris: ephemeris) }
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try observer.astrometricPlace(of: .mars, at: tdb, ephemeris: ephemeris) }
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try observer.apparentPlace(of: star, at: tdb, ephemeris: ephemeris) }
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try observer.astrometricPlace(of: star, at: tdb, ephemeris: ephemeris) }
	}

	@Test func unalteredEphemerisMatchesTheBuiltIn() throws {
		let ephemeris = AlteredEarthEphemeris()
		#expect(try Observer.geocenter.apparentPlace(of: .mars, at: Self.tdb, ephemeris: ephemeris) == Observer.geocenter.apparentPlace(of: .mars, at: Self.tdb))
		#expect(try Observer.geocenter.apparentPlace(of: Self.star, at: Self.tdb, ephemeris: ephemeris) == Observer.geocenter.apparentPlace(of: Self.star, at: Self.tdb))
	}

	@Test func nanEarthVelocity() {
		// Finite positions with a NaN velocity once passed through aberration as NaN coordinates.
		Self.expectInvalidState(AlteredEarthEphemeris(velocity: SIMD3(0.01, .nan, 0)))
	}

	@Test func nonFiniteEarthPosition() {
		Self.expectInvalidState(AlteredEarthEphemeris(position: SIMD3(.infinity, 0, 0)))
		Self.expectInvalidState(AlteredEarthEphemeris(position: SIMD3(1, .nan, 0)))
	}

	@Test func earthAtTheSpeedOfLight() {
		let c = speedOfLightAstronomicalUnitsPerDay
		Self.expectInvalidState(AlteredEarthEphemeris(velocity: SIMD3(0, c, 0)))
		Self.expectInvalidState(AlteredEarthEphemeris(velocity: SIMD3(0, 2 * c, 0)))
		// A finite velocity whose speed overflows
		Self.expectInvalidState(AlteredEarthEphemeris(velocity: SIMD3(1e300, 1e300, 0)))
	}

	@Test func earthAtTheSun() {
		// Finite states, but the Sun's potential at the observer is infinite.
		Self.expectApparentInvalidState(AlteredEarthEphemeris(position: SIMD3(0, 0, 0)))
	}

	/// Expects the apparent places of a body and a star to throw ``EphemerisError/invalidState``.
	static func expectApparentInvalidState(_ ephemeris: AlteredEarthEphemeris, sourceLocation: SourceLocation = #_sourceLocation) {
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try Observer.geocenter.apparentPlace(of: .mars, at: tdb, ephemeris: ephemeris) }
		#expect(throws: EphemerisError.invalidState, sourceLocation: sourceLocation) { try Observer.geocenter.apparentPlace(of: star, at: tdb, ephemeris: ephemeris) }
	}

	@Test func validStatesPass() throws {
		// Just below the speed of light is allowed, and gives finite places.
		let ephemeris = AlteredEarthEphemeris(velocity: SIMD3(0, 0.9 * speedOfLightAstronomicalUnitsPerDay, 0))
		let place = try Observer.geocenter.apparentPlace(of: .mars, at: Self.tdb, ephemeris: ephemeris)
		#expect(place.position.x.astronomicalUnits.isFinite && place.position.y.astronomicalUnits.isFinite && place.position.z.astronomicalUnits.isFinite)
	}
}
