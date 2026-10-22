//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Star {
	/// Returns the star's catalog values at another epoch.
	///
	/// The star moves in a straight line at constant speed, following `eraStarpm` of ERFA: the
	/// result is the direction from which its light reaches the solar system barycenter at
	/// `epoch`, with the proper motion, parallax, and radial velocity seen there. The right
	/// ascension is in [0°, 360°).
	///
	/// A star without a parallax has none at the new epoch. A star with a parallax too small for
	/// its proper motion, as described for ``Star``, has the parallax of the distance its motion
	/// is taken at.
	///
	/// - Parameter epoch: The new epoch.
	/// - Returns: The star at `epoch`.
	/// - Throws:
	///   - ``StarError/excessiveTimeSpan`` if `epoch` is more than 10 million Julian years from
	///     the star's epoch.
	///   - ``StarError/withinSolarSystem`` if at `epoch` the star is within about 20,600 au of
	///     the barycenter, where its parallax would be more than 10″.
	///   - ``StarError/excessiveRadialVelocity`` if the radial velocity seen at `epoch` is half
	///     the speed of light or more, as only a star moving at nearly that speed can reach.
	public func propagated(to epoch: Instant<TDB>) throws(StarError) -> Star {
		let c = speedOfLightAstronomicalUnitsPerDay
		let motion = spaceMotion()
		let position = try barycentricPlace(motion, daysSinceEpoch: Astrometry.days(from: self.epoch, to: epoch))
		let velocity = motion.velocity

		// The inertial velocity to the observed one, as in `eraPvstar`
		let distance = position.length
		guard 1 / distance <= Self.maximumParallax.radians else { throw .withinSolarSystem }
		let u = position / distance
		let radial = u.dot(velocity)
		let transverse = velocity - u * radial
		let betaR = radial / c
		let betaT = transverse.length / c
		let d = 1 + betaR
		let w = betaR * betaR + betaT * betaT
		let del = -w / ((1 - w).squareRoot() + 1)
		let observedTransverse = transverse / d
		let observedRadial = c * (betaR - del) / d
		guard abs(observedRadial) < Self.maximumSpeed else { throw .excessiveRadialVelocity }

		let rightAscension = Math.atan2(position.y, position.x)
		let declination = Math.atan2(position.z, (position.x * position.x + position.y * position.y).squareRoot())
		let (alpha, delta) = Self.unitVectors(rightAscension: rightAscension, declination: declination)
		let scale = daysPerJulianYear / distance
		return Star(
			uncheckedRightAscension: Angle(radians: rightAscension < 0 ? rightAscension + twoPi : rightAscension),
			declination: Angle(radians: declination),
			properMotionInRightAscension: Angle(radians: observedTransverse.dot(alpha) * scale),
			properMotionInDeclination: Angle(radians: observedTransverse.dot(delta) * scale),
			parallax: parallax.map { _ in Angle(radians: 1 / distance) },
			radialVelocity: Speed(astronomicalUnitsPerDay: observedRadial),
			epoch: epoch)
	}
}

extension Star {
	/// The parallax of a source at 1 Gpc, the least used for the space motion, in radians.
	static let minimumParallax = 1e-9 / arcsecondsPerRadian

	/// The parallax, in arcseconds, per proper motion, in radians per year, below which the
	/// transverse speed would exceed about 1% of the speed of light: the factor of
	/// `eraPmsafe` of ERFA.
	static let parallaxPerProperMotion: Double = 326

	/// Whether the parallax gives the distance used for the space motion, so that the star's
	/// place can be found from its position relative to the observer.
	var hasDistance: Bool {
		(parallax?.radians ?? 0) >= effectiveParallax
	}

	/// The parallax used for the space motion, in radians.
	var effectiveParallax: Double {
		let properMotion = (properMotionInRightAscension.radians * properMotionInRightAscension.radians + properMotionInDeclination.radians * properMotionInDeclination.radians).squareRoot()
		return max(parallax?.radians ?? 0, properMotion * Self.parallaxPerProperMotion / arcsecondsPerRadian, Self.minimumParallax)
	}

	/// Returns the unit vectors of increasing right ascension and declination at a place.
	static func unitVectors(rightAscension: Double, declination: Double) -> (alpha: Vector3, delta: Vector3) {
		let (sinA, cosA) = Math.sincos(rightAscension)
		let (sinD, cosD) = Math.sincos(declination)
		return (Vector3(-sinA, cosA, 0), Vector3(-sinD * cosA, -sinD * sinA, cosD))
	}

	/// Returns the star's barycentric position, in au, and inertial velocity, in au/day, at
	/// the epoch, following `eraStarpv` of ERFA.
	///
	/// The position is where the star was when the light that reached the barycenter at the
	/// epoch left it. The catalog's proper motion and radial velocity are observed ones, which
	/// the changing light time scales by the Doppler factor; they are corrected to inertial ones
	/// by iteration.
	func spaceMotion() -> (position: Vector3, velocity: Vector3) {
		let c = speedOfLightAstronomicalUnitsPerDay
		let distance = 1 / effectiveParallax
		let (sinA, cosA) = Math.sincos(rightAscension.radians)
		let (sinD, cosD) = Math.sincos(declination.radians)
		let u = Vector3(cosD * cosA, cosD * sinA, sinD)
		let (alpha, delta) = Self.unitVectors(rightAscension: rightAscension.radians, declination: declination.radians)
		let transverse = (alpha * properMotionInRightAscension.radians + delta * properMotionInDeclination.radians) * (distance / daysPerJulianYear)
		let betaSR = radialVelocity.astronomicalUnitsPerDay / c
		let betaST = transverse.length / c

		// The observed-to-inertial correction terms, iterated until they stop improving
		var betaR = betaSR
		var betaT = betaST
		var d = 0.0
		var del = 0.0
		var (previousD, previousDel, previousDD, previousDDel) = (0.0, 0.0, 0.0, 0.0)
		for i in 0 ..< 100 {
			d = 1 + betaR
			let w = betaR * betaR + betaT * betaT
			del = -w / ((1 - w).squareRoot() + 1)
			betaR = d * betaSR + del
			betaT = d * betaST
			if i > 0 {
				let dd = abs(d - previousD)
				let ddel = abs(del - previousDel)
				if i > 1, dd >= previousDD, ddel >= previousDDel {
					break
				}
				previousDD = dd
				previousDDel = ddel
			}
			previousD = d
			previousDel = del
		}
		return (u * distance, transverse * d + u * (c * (d * betaSR + del)))
	}

	/// Returns where the star was when the light reaching the barycenter at an instant left it,
	/// relative to the barycenter, checking that the star is a star at that instant.
	///
	/// - Parameters:
	///   - motion: The star's space motion, from ``spaceMotion()``.
	///   - days: The instant, in TDB days after the epoch.
	/// - Returns: The position relative to the barycenter, in au.
	/// - Throws:
	///   - ``StarError/excessiveTimeSpan`` if the instant is more than 10 million Julian years
	///     from the epoch.
	///   - ``StarError/withinSolarSystem`` if the star is within about 20,600 au of the
	///     barycenter.
	func barycentricPlace(_ motion: (position: Vector3, velocity: Vector3), daysSinceEpoch days: Double) throws(StarError) -> Vector3 {
		guard abs(days) <= Self.maximumTimeSpan else {
			throw .excessiveTimeSpan
		}
		let barycentric = Self.observed(motion, daysSinceEpoch: days, from: Vector3(0, 0, 0)).relative
		guard barycentric.length * Self.maximumParallax.radians >= 1 else {
			throw .withinSolarSystem
		}
		return barycentric
	}

	/// Returns where the star was when the light reaching an observer at an instant left it,
	/// relative to the observer, and the light time.
	///
	/// A star whose parallax gives its distance is found from its position relative to the
	/// observer. Any other is found as seen from the barycenter when its light passes the
	/// observer, shifted by its parallax, if any, and placed at the distance of its parallax,
	/// or at 1 Gpc.
	///
	/// - Parameters:
	///   - days: The instant, in TDB days after the epoch.
	///   - observer: The barycentric position of the observer, in au, within 10,000 au of the
	///     barycenter. With the star at least 20,600 au from it, and moving under c/2 over the
	///     few thousand au that the light times differ by, the star is at least 5,000 au from
	///     the observer.
	/// - Returns: The position relative to the observer, in au, and the light time, in days.
	/// - Throws: A ``StarError``, as ``barycentricPlace(_:daysSinceEpoch:)`` does.
	func observed(daysSinceEpoch days: Double, from observer: Vector3) throws(StarError) -> (relative: Vector3, lightTime: Double) {
		let motion = spaceMotion()
		let barycentric = try barycentricPlace(motion, daysSinceEpoch: days)
		if hasDistance {
			return Self.observed(motion, daysSinceEpoch: days, from: observer)
		}
		// The light reaches the observer earlier than the barycenter by the Rømer delay.
		let romerDelay = barycentric.dot(observer) / barycentric.length / speedOfLightAstronomicalUnitsPerDay
		let delayed = Self.observed(motion, daysSinceEpoch: days + romerDelay, from: Vector3(0, 0, 0)).relative
		let direction = delayed / delayed.length - observer * (parallax?.radians ?? 0)
		let distance = 1 / max(parallax?.radians ?? 0, Self.minimumParallax)
		return (direction * (distance / direction.length), distance / speedOfLightAstronomicalUnitsPerDay)
	}

	/// Returns where a star was when the light reaching a point at an instant left it, relative
	/// to that point, and the light time.
	///
	/// Following `eraStarpm` of ERFA, the star moves from its position at the epoch, which it
	/// held a light time before the epoch, to its position at the instant, and back along its
	/// motion by the light time τ that solves |r - vτ| = cτ, where r is its position at the
	/// instant relative to the point.
	///
	/// - Parameters:
	///   - motion: The star's space motion, from ``spaceMotion()``.
	///   - days: The instant, in TDB days after the epoch.
	///   - point: The barycentric position of the point, in au.
	/// - Returns: The position relative to the point, in au, and the light time, in days.
	static func observed(_ motion: (position: Vector3, velocity: Vector3), daysSinceEpoch days: Double, from point: Vector3) -> (relative: Vector3, lightTime: Double) {
		let c = speedOfLightAstronomicalUnitsPerDay
		let (position, velocity) = motion
		let now = position + velocity * (days + position.length / c) - point
		let r2 = now.dot(now)
		let rdv = now.dot(velocity)
		let c2mv2 = c * c - velocity.dot(velocity)
		let root = (rdv * rdv + c2mv2 * r2).squareRoot()
		// The root of c²τ² = |r - vτ|², in the form that avoids cancellation
		let lightTime = rdv >= 0 ? r2 / (rdv + root) : (root - rdv) / c2mv2
		return (now - velocity * lightTime, lightTime)
	}
}
