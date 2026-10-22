//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The corrections from geometric to astrometric and apparent places: light time, the
/// gravitational deflection of light, and aberration, following the Explanatory Supplement to
/// the Astronomical Almanac (2013), Chapter 7, and ERFA.
///
/// Positions here are barycentric, in astronomical units in ICRS axes, at TDB.
enum Astrometry {
	/// The barycentric positions of the bodies of an observation, from states relative to the
	/// Sun and the Sun's barycentric state at the instant of observation.
	///
	/// A state relative to the barycenter can cost far more than one relative to the Sun, as in
	/// ``SolarSystemEphemeris``, where the barycenter needs every body. The Sun's barycentric
	/// motion is carried back linearly over the light time, which neglects its acceleration:
	/// under 50 m over Pluto's light time of five hours.
	///
	/// Every state is checked as it is read, so that an ephemeris's NaN, infinite, or faster
	/// than light values throw ``EphemerisError/invalidState`` instead of reaching the places.
	struct Positions<E: GeocentricEphemeris> {
		let ephemeris: E
		/// The instant of observation.
		let tdb: Instant<TDB>
		/// The Sun's barycentric position and velocity at the instant of observation.
		let sun: (position: Vector3, velocity: Vector3)

		init(ephemeris: E, at tdb: Instant<TDB>) throws(EphemerisError) {
			self.ephemeris = ephemeris
			self.tdb = tdb
			let state = try ephemeris.state(of: E.sun, relativeTo: E.solarSystemBarycenter, at: tdb).converted(to: ICRS.self)
			sun = try Self.validated(state.position.vector, state.velocity.vector)
		}

		/// Returns a body's barycentric position and velocity some days before the instant of
		/// observation.
		func state(of body: E.Body, daysEarlier days: Double = 0) throws(EphemerisError) -> (position: Vector3, velocity: Vector3) {
			let instant = days == 0 ? tdb : try Astrometry.instant(tdb, minusDays: days)
			let heliocentric = try ephemeris.state(of: body, relativeTo: E.sun, at: instant).converted(to: ICRS.self)
			return try Self.validated(heliocentric.position.vector + sun.position - sun.velocity * days, heliocentric.velocity.vector + sun.velocity)
		}

		/// Returns a state, checked to be finite and slower than light.
		///
		/// - Throws: ``EphemerisError/invalidState`` if a component is NaN or infinite, or the
		///   speed is the speed of light or more, outside the domain of aberration.
		static func validated(_ position: Vector3, _ velocity: Vector3) throws(EphemerisError) -> (position: Vector3, velocity: Vector3) {
			let components = [position.x, position.y, position.z, velocity.x, velocity.y, velocity.z]
			guard components.allSatisfy(\.isFinite), velocity.length < speedOfLightAstronomicalUnitsPerDay else {
				throw .invalidState
			}
			return (position, velocity)
		}
	}

	/// The geometry of an observation: where the observer was at the instant of observation and
	/// where the target was when the light left it.
	struct Geometry {
		/// The observer's barycentric position and velocity at the instant of observation.
		let observer: (position: Vector3, velocity: Vector3)
		/// The target's barycentric position when the light left it.
		let target: Vector3
		/// The light time, in days.
		let lightTime: Double
	}

	/// Returns a TDB instant some days earlier.
	static func instant(_ tdb: Instant<TDB>, minusDays days: Double) throws(EphemerisError) -> Instant<TDB> {
		do throws(JulianDateError) {
			return Instant(try tdb.julianDate.adding(days: -days))
		} catch {
			throw .outsideCoverage
		}
	}

	/// Returns the number of days from one TDB instant to another.
	static func days(from start: Instant<TDB>, to end: Instant<TDB>) -> Double {
		differenceAsDouble(end.julianDate.julianDayNumber, start.julianDate.julianDayNumber) + (end.julianDate.fractionFromNoon - start.julianDate.fractionFromNoon)
	}

	/// Finds where the target was when the light seen by the observer left it.
	///
	/// The light time τ solves τ = |r_T(t - τ) - r_O(t)| / c + Δt_S, where Δt_S is the Shapiro
	/// delay in the Sun's field, by iteration from τ = 0 to 1e-14 day. The Sun as the target has
	/// no Shapiro delay, which diverges at its center.
	///
	/// - Parameters:
	///   - body: The target.
	///   - observer: The observer's barycentric position and velocity at the instant of
	///     observation.
	///   - positions: The positions of the ephemeris.
	static func geometry<E: GeocentricEphemeris>(of body: E.Body, observer: (position: Vector3, velocity: Vector3), positions: Positions<E>) throws(EphemerisError) -> Geometry {
		let sun = positions.sun.position
		let sunGravitationalParameter = body == E.sun ? 0 : E.lightDeflectingBodies.first { $0.body == E.sun }?.gravitationalParameter ?? 0
		var lightTime = 0.0
		var target = try positions.state(of: body).position
		for _ in 0 ..< 10 {
			let separation = (target - observer.position).length
			let delay = shapiroDelay(observerDistance: (observer.position - sun).length, targetDistance: (target - sun).length, separation: separation, gravitationalParameter: sunGravitationalParameter)
			let next = separation / speedOfLightAstronomicalUnitsPerDay + delay
			let converged = abs(next - lightTime) < 1e-14
			lightTime = next
			target = try positions.state(of: body, daysEarlier: lightTime).position
			if converged {
				break
			}
		}
		return Geometry(observer: observer, target: target, lightTime: lightTime)
	}

	/// Returns the Shapiro delay of light in a body's field, (2GM/c³) ln((r_O + r_T + R) /
	/// (r_O + r_T - R)).
	///
	/// - Parameters:
	///   - observerDistance: The observer's distance from the body, r_O, in au.
	///   - targetDistance: The target's distance from the body, r_T, in au.
	///   - separation: The distance from the observer to the target, R, in au.
	///   - gravitationalParameter: The body's GM, in au³/day².
	/// - Returns: The delay, in days.
	static func shapiroDelay(observerDistance: Double, targetDistance: Double, separation: Double, gravitationalParameter: Double) -> Double {
		let denominator = observerDistance + targetDistance - separation
		guard gravitationalParameter > 0, denominator > 0, separation > 0 else { return 0 }
		let c = speedOfLightAstronomicalUnitsPerDay
		return 2 * gravitationalParameter / (c * c * c) * Math.log((observerDistance + targetDistance + separation) / denominator)
	}

	/// Returns a direction deflected by one body, following `eraLd` of ERFA for a source at a
	/// finite distance: p + (2GM / (c² d)) p × (e × q) / max(q · (q + e), limit), where p is the
	/// direction to the source, q the direction from the body to the source, and e and d the
	/// direction and distance from the body to the observer (Explanatory Supplement, Section
	/// 7.2.4).
	///
	/// - Parameters:
	///   - p: The unit vector from the observer to the source.
	///   - q: The unit vector from the body to the source.
	///   - e: The unit vector from the body to the observer.
	///   - distance: The distance from the body to the observer, d, in au.
	///   - gravitationalParameter: The body's GM, in au³/day².
	///   - limit: The least value of q · (q + e).
	/// - Returns: The deflected direction, not normalized.
	static func deflected(_ p: Vector3, q: Vector3, e: Vector3, distance: Double, gravitationalParameter: Double, limit: Double) -> Vector3 {
		let c = speedOfLightAstronomicalUnitsPerDay
		let w = 2 * gravitationalParameter / (c * c) / distance / max(q.dot(q + e), limit)
		return p + p.cross(e.cross(q)) * w
	}

	/// Returns a direction deflected by the gravity of the light-deflecting bodies.
	///
	/// Each body is placed where it was when the light passed it, backtracked along its
	/// velocity, as `eraLdn` of ERFA does, and the farthest bodies deflect the light first. No
	/// deflection is applied when the light's path from the target passes within the body's
	/// radius, as for a target behind the body's disk, and a body that is the target deflects
	/// nothing.
	///
	/// - Parameters:
	///   - direction: The unit vector from the observer to the source.
	///   - geometry: The observation.
	///   - body: The target, or `nil` for a source outside the ephemeris.
	///   - positions: The positions of the ephemeris.
	/// - Returns: The deflected unit vector.
	static func deflected<E: GeocentricEphemeris>(_ direction: Vector3, geometry: Geometry, of body: E.Body?, positions: Positions<E>) throws(EphemerisError) -> Vector3 {
		let c = speedOfLightAstronomicalUnitsPerDay
		var deflectors: [(position: Vector3, gravitationalParameter: Double, radius: Double)] = []
		for deflector in E.lightDeflectingBodies where deflector.body != body {
			let state = try positions.state(of: deflector.body)
			// The time since the light passed the body, between the target's and the observer's
			let toObserver = geometry.observer.position - state.position
			let elapsed = min(max(direction.dot(toObserver) / c, -geometry.lightTime), 0)
			deflectors.append((state.position + state.velocity * elapsed, deflector.gravitationalParameter, deflector.radius.astronomicalUnits))
		}
		deflectors.sort { ($0.position - geometry.observer.position).length > ($1.position - geometry.observer.position).length }
		var p = direction
		for deflector in deflectors {
			let toObserver = geometry.observer.position - deflector.position
			let distance = toObserver.length
			let toTarget = geometry.target - deflector.position
			guard closestApproach(of: deflector.position, from: geometry.observer.position, to: geometry.target) > deflector.radius else { continue }
			let q = toTarget / toTarget.length
			let e = toObserver / distance
			p = deflected(p, q: q, e: e, distance: distance, gravitationalParameter: deflector.gravitationalParameter, limit: 0)
		}
		return p / p.length
	}

	/// Returns the least distance of a point from the segment between two others, as of a body
	/// from the path of light from a target to an observer.
	static func closestApproach(of point: Vector3, from start: Vector3, to end: Vector3) -> Double {
		let segment = end - start
		let length2 = segment.dot(segment)
		guard length2 > 0 else { return (point - start).length }
		let fraction = min(max((point - start).dot(segment) / length2, 0), 1)
		return (point - (start + segment * fraction)).length
	}

	/// Returns a direction corrected for aberration, following `eraAb` of ERFA, with the
	/// relativistic terms and the Sun's gravitational potential.
	///
	/// - Parameters:
	///   - direction: The unit vector from the observer to the source, corrected for
	///     deflection.
	///   - velocity: The observer's barycentric velocity, in au/day.
	///   - sunDistance: The observer's distance from the Sun, in au.
	///   - sunGravitationalParameter: The Sun's GM, in au³/day².
	/// - Returns: The apparent unit vector.
	static func aberrated(_ direction: Vector3, velocity: Vector3, sunDistance: Double, sunGravitationalParameter: Double) -> Vector3 {
		let c = speedOfLightAstronomicalUnitsPerDay
		let v = velocity / c
		let bm1 = (1 - v.dot(v)).squareRoot()
		let pdv = direction.dot(v)
		let w1 = 1 + pdv / (1 + bm1)
		// The Sun's Schwarzschild radius over the distance
		let w2 = 2 * sunGravitationalParameter / (c * c) / sunDistance
		let p = direction * bm1 + v * w1 + (v - direction * pdv) * w2
		return p / p.length
	}
}
