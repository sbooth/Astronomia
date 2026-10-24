//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Observation {
	/// Returns how a body is lit by the Sun as the observer sees it.
	///
	/// - Parameter body: The body.
	/// - Returns: The body's phase angle, illuminated fraction, elongation and its side of the
	///   Sun, and bright limb.
	/// - Throws:
	///   - ``IlluminationError/notIlluminated`` if the body is the Sun, or the Earth, on or in
	///     which the observer is.
	///   - ``IlluminationError/ephemeris(_:)`` if the place of the body or the Sun fails, as
	///     for ``apparentPlace(of:)``.
	public func illumination(of body: E.Body) throws(IlluminationError) -> Illumination {
		guard body != E.sun, body != E.earth else {
			throw .notIlluminated
		}
		do throws(EphemerisError) {
			let geometry = try Astrometry.geometry(of: body, observer: observerVectors, positions: positions)
			let toBody = geometry.target - geometry.observer.position

			// The Sun when it emitted the light that the body reflects toward the observer, a
			// light time before the body's light left it, its barycentric motion carried back
			// linearly
			let sun = positions.sun
			let sunAtBody = sun.position - sun.velocity * geometry.lightTime
			let sunLightTime = (geometry.target - sunAtBody).length / speedOfLightAstronomicalUnitsPerDay
			let fromSun = geometry.target - (sunAtBody - sun.velocity * sunLightTime)
			// The angle at the body between the directions to the Sun and to the observer
			let phaseAngle = Angle.atan2(y: toBody.cross(fromSun).length, x: toBody.dot(fromSun))

			// The apparent directions of the body and the Sun, in the true equator of date
			let bodyApparent = apparentDirection(toBody / toBody.length, geometry: geometry, excluding: body)
			let sunApparent = try apparentPlace(of: E.sun).position.vector
			guard bodyApparent.x.isFinite, bodyApparent.y.isFinite, bodyApparent.z.isFinite else {
				throw .invalidState
			}
			let elongation = Angle.atan2(y: bodyApparent.cross(sunApparent).length, x: bodyApparent.dot(sunApparent))
			let toDate = TrueEquatorOfDate.rotationFromICRS(at: instant, earthOrientation: earthOrientation)
			let b = toDate.apply(to: bodyApparent)
			let s = toDate.apply(to: sunApparent)
			// The Sun's direction along the body's east and north, ẑ × b and ẑ - (ẑ · b) b, which
			// have the same length
			let east = s.dot(Vector3(0, 0, 1).cross(b))
			let north = s.z - b.z * s.dot(b)
			let brightLimb = Angle.atan2(y: east, x: north).normalized()
			// The body is east of the Sun if its longitude exceeds the Sun's by under 180°: the
			// component of s × b along the pole of the ecliptic, cos β_S cos β_B sin(λ_B - λ_S),
			// is positive.
			let toEcliptic = TrueEclipticOfDate.rotationFromICRS(at: instant, earthOrientation: earthOrientation)
			let isEastOfSun = toEcliptic.apply(to: sunApparent).cross(toEcliptic.apply(to: bodyApparent)).z > 0
			return Illumination(phaseAngle: phaseAngle, elongation: elongation, isEastOfSun: isEastOfSun, brightLimbPositionAngle: brightLimb, instant: instant)
		} catch {
			throw .ephemeris(error)
		}
	}
}
