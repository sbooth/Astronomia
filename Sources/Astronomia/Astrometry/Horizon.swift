//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A site's horizon at an instant: the rotation from the GCRS to the ITRS, and the site's
/// local axes in the ITRS.
struct Horizon: Sendable {
	/// The rotation from the GCRS to the ITRS at the instant.
	let toITRS: Rotation<ICRS, ITRS>
	/// The sine and cosine of the geodetic latitude.
	let sinLatitude: Double
	let cosLatitude: Double
	/// The unit vectors toward the east, the north, and the zenith, in the ITRS.
	let east: Vector3
	let north: Vector3
	let up: Vector3

	/// The least distance of a direction from the zenith, in the plane of the horizon, at
	/// which refraction is found, as `CELMIN` of `eraAtioq`.
	static let minimumHorizontal = 1e-6
	/// The least height of a direction above the horizon at which refraction is found, the
	/// sine of an altitude of about 2.9°, as `SELMIN` of `eraAtioq`.
	static let minimumVertical = 0.05

	/// Creates a site's horizon.
	///
	/// - Parameters:
	///   - toITRS: The rotation from the GCRS to the ITRS at the instant.
	///   - latitude: The geodetic latitude, in radians.
	///   - longitude: The longitude, in radians.
	init(toITRS: Rotation<ICRS, ITRS>, latitude: Double, longitude: Double) {
		let (sinPhi, cosPhi) = Math.sincos(latitude)
		let (sinLambda, cosLambda) = Math.sincos(longitude)
		self.toITRS = toITRS
		self.sinLatitude = sinPhi
		self.cosLatitude = cosPhi
		self.east = Vector3(-sinLambda, cosLambda, 0)
		self.north = Vector3(-sinPhi * cosLambda, -sinPhi * sinLambda, cosPhi)
		self.up = Vector3(cosPhi * cosLambda, cosPhi * sinLambda, sinPhi)
	}

	/// Returns the parallactic angle, following `eraHd2pa` of ERFA.
	///
	/// - Parameters:
	///   - hourAngle: The hour angle, in radians.
	///   - declination: The declination, in radians.
	///   - sinLatitude: The sine of the site's latitude.
	///   - cosLatitude: The cosine of the site's latitude.
	/// - Returns: The parallactic angle, in radians in the left-open interval (-π, π].
	static func parallacticAngle(hourAngle: Double, declination: Double, sinLatitude: Double, cosLatitude: Double) -> Double {
		let (sinH, cosH) = Math.sincos(hourAngle)
		let (sinDelta, cosDelta) = Math.sincos(declination)
		let y = cosLatitude * sinH
		let x = sinLatitude * cosDelta - cosLatitude * sinDelta * cosH
		// At the pole, or at the zenith, both are zero, and the angle is taken as 0.
		guard y != 0 || x != 0 else { return 0 }
		let angle = Math.atan2(y, x)
		return angle == -.pi ? .pi : angle
	}

	/// Returns the observed place of a direction, following `eraAtioq` of ERFA.
	///
	/// - Parameters:
	///   - direction: The unit vector of the apparent direction, in the GCRS.
	///   - refraction: The refraction constants A and B, in radians, or `nil` for none.
	///   - distance: The distance of the target.
	///   - instant: The instant of observation.
	/// - Returns: The observed place.
	func observedPlace(of direction: Vector3, refraction: (a: Double, b: Double)?, distance: Distance, instant: Instant<TT>) -> ObservedPlace {
		let terrestrial = toITRS.apply(to: direction)
		let e = terrestrial.dot(east)
		let n = terrestrial.dot(north)
		let u = terrestrial.dot(up)
		let azimuth = Math.atan2(e, n)

		// The refraction raises the direction toward the zenith by δ, the angle of
		// A tan z + B tan³ z refined by one Newton step, as in `eraAtioq`.
		var (observedE, observedN, observedU) = (e, n, u)
		if let refraction {
			let horizontal = max((e * e + n * n).squareRoot(), Self.minimumHorizontal)
			let vertical = max(u, Self.minimumVertical)
			let tanZ = horizontal / vertical
			let w = refraction.b * tanZ * tanZ
			let delta = (refraction.a + w) * tanZ / (1 + (refraction.a + 3 * w) / (vertical * vertical))
			let cosDelta = 1 - delta * delta / 2
			let f = cosDelta - delta * vertical / horizontal
			observedE = e * f
			observedN = n * f
			observedU = cosDelta * u + delta * horizontal
		}
		let altitude = Math.atan2(observedU, (observedE * observedE + observedN * observedN).squareRoot())

		// The direction toward the meridian on the site's equator, and toward its pole
		let meridian = cosLatitude * observedU - sinLatitude * observedN
		let pole = cosLatitude * observedN + sinLatitude * observedU
		// atan2 gives -π for the lower meridian, which the hour angle includes as +π.
		let hourAngle = Math.atan2(-observedE, meridian)
		let declination = Math.atan2(pole, (meridian * meridian + observedE * observedE).squareRoot())
		return ObservedPlace(
			azimuth: Angle(radians: azimuth).normalized(),
			altitude: Angle(radians: altitude),
			hourAngle: Angle(radians: hourAngle == -.pi ? .pi : hourAngle),
			declination: Angle(radians: declination),
			parallacticAngle: Angle(radians: Self.parallacticAngle(hourAngle: hourAngle, declination: declination, sinLatitude: sinLatitude, cosLatitude: cosLatitude)),
			distance: distance,
			instant: instant)
	}
}
