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

	/// The longest span, in days, over which ``geometry(of:observer:positions:)`` carries the
	/// target along its velocity instead of evaluating the ephemeris again.
	///
	/// Over 1e-5 day, under a second, a target's acceleration moves it from its tangent by
	/// about 2 cm at most, for Mercury's 3e-3 au/day² about the Sun.
	static let maximumExtrapolation = 1e-5

	/// Finds where the target was when the light seen by the observer left it.
	///
	/// The light time τ solves τ = |r_T(t - τ) - r_O(t)| / c + Δt_S, where Δt_S is the Shapiro
	/// delay in the Sun's field. The Sun as the target has no Shapiro delay, which diverges at
	/// its center.
	///
	/// The target is evaluated at the instant of observation, which gives a first light time,
	/// and again that light time earlier. From there the solution iterates to 1e-14 day with
	/// the target carried along its velocity, and the ephemeris is evaluated again only if the
	/// solution moves more than ``maximumExtrapolation`` from where it was evaluated. A light
	/// time changes by about the target's radial speed over c, so for the bodies of the solar
	/// system two evaluations suffice.
	///
	/// - Parameters:
	///   - body: The target.
	///   - observer: The observer's barycentric position and velocity at the instant of
	///     observation.
	///   - positions: The positions of the ephemeris.
	/// - Throws: ``EphemerisError/invalidState`` if the light time doesn't converge, for a
	///   target moving at nearly the speed of light, or an ``EphemerisError`` from the
	///   ephemeris.
	static func geometry<E: GeocentricEphemeris>(of body: E.Body, observer: (position: Vector3, velocity: Vector3), positions: Positions<E>) throws(EphemerisError) -> Geometry {
		let sun = positions.sun.position
		let sunGravitationalParameter = body == E.sun ? 0 : E.lightDeflectingBodies.first { $0.body == E.sun }?.gravitationalParameter ?? 0
		/// Returns the light time from a place of the target.
		func lightTime(from target: Vector3) -> Double {
			let separation = (target - observer.position).length
			let delay = shapiroDelay(observerDistance: (observer.position - sun).length, targetDistance: (target - sun).length, separation: separation, gravitationalParameter: sunGravitationalParameter)
			return separation / speedOfLightAstronomicalUnitsPerDay + delay
		}

		// The target's state, evaluated this many days before the instant of observation
		var evaluatedAt = 0.0
		var state = try positions.state(of: body)
		var solution = 0.0
		for _ in 0 ..< 5 {
			var converged = false
			for _ in 0 ..< 10 {
				let next = lightTime(from: state.position - state.velocity * (solution - evaluatedAt))
				converged = abs(next - solution) < 1e-14
				solution = next
				if converged {
					break
				}
			}
			guard converged else {
				throw .invalidState
			}
			if abs(solution - evaluatedAt) <= maximumExtrapolation {
				return Geometry(observer: observer, target: state.position - state.velocity * (solution - evaluatedAt), lightTime: solution)
			}
			state = try positions.state(of: body, daysEarlier: solution)
			evaluatedAt = solution
		}
		throw .invalidState
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

	/// A light-deflecting body at the instant of observation.
	struct Deflector<Body: Hashable & Sendable>: Sendable {
		/// The body.
		let body: Body
		/// The body's barycentric position and velocity at the instant of observation.
		let state: (position: Vector3, velocity: Vector3)
		/// The body's gravitational parameter, in au³/day².
		let gravitationalParameter: Double
		/// The body's radius, in au.
		let radius: Double
		/// Whether the observer is on the body's surface, so that light from above its horizon
		/// is deflected by it, and light from below passes through it.
		let isObserversBody: Bool
	}

	/// Returns a direction deflected by the gravity of the light-deflecting bodies.
	///
	/// Each body is placed where it was when the light passed it, backtracked along its
	/// velocity, as `eraLdn` of ERFA does, and the farthest bodies deflect the light first. No
	/// deflection is applied when the light's path from the target passes within the body's
	/// radius, as for a target behind the body's disk, and a body that is the target deflects
	/// nothing. For an observer on a body's surface, as on the Earth, the body deflects light
	/// from above the horizon, the plane through the observer perpendicular to the direction
	/// from the body's center: there q · (q + e) is about 1 or more, and the deflection about
	/// its value at the limb at most, while light from below would pass through the body.
	///
	/// - Parameters:
	///   - direction: The unit vector from the observer to the source.
	///   - geometry: The observation.
	///   - deflectors: The light-deflecting bodies at the instant of observation.
	///   - body: The target, or `nil` for a source outside the ephemeris.
	/// - Returns: The deflected unit vector.
	static func deflected<Body>(_ direction: Vector3, geometry: Geometry, deflectors: [Deflector<Body>], excluding body: Body?) -> Vector3 {
		let c = speedOfLightAstronomicalUnitsPerDay
		var backtracked: [(position: Vector3, gravitationalParameter: Double, radius: Double, isObserversBody: Bool)] = []
		for deflector in deflectors where deflector.body != body {
			// The time since the light passed the body, between the target's and the observer's
			let toObserver = geometry.observer.position - deflector.state.position
			let elapsed = min(max(direction.dot(toObserver) / c, -geometry.lightTime), 0)
			backtracked.append((deflector.state.position + deflector.state.velocity * elapsed, deflector.gravitationalParameter, deflector.radius, deflector.isObserversBody))
		}
		backtracked.sort { ($0.position - geometry.observer.position).length > ($1.position - geometry.observer.position).length }
		var p = direction
		for deflector in backtracked {
			let toObserver = geometry.observer.position - deflector.position
			let distance = toObserver.length
			if deflector.isObserversBody {
				// A site on an ellipsoid can be inside the body's equatorial radius, so its
				// horizon decides instead.
				guard p.dot(toObserver) >= 0 else { continue }
			} else {
				guard closestApproach(of: deflector.position, from: geometry.observer.position, to: geometry.target) > deflector.radius else { continue }
			}
			let toTarget = geometry.target - deflector.position
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
		// The Sun's Schwarzschild radius over the distance, if the Sun has a mass
		let w2 = sunGravitationalParameter > 0 ? 2 * sunGravitationalParameter / (c * c) / sunDistance : 0
		let p = direction * bm1 + v * w1 + (v - direction * pdv) * w2
		return p / p.length
	}
}
