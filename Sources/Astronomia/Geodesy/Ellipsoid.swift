//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A reference ellipsoid for the Earth, on which geodetic latitude, longitude, and height are
/// measured.
///
/// The two differ in flattening only, by about 0.1 mm in the polar radius.
public enum Ellipsoid: Hashable, Sendable, CaseIterable {
	/// The World Geodetic System 1984, used by GPS.
	case wgs84
	/// The Geodetic Reference System 1980, used by the ITRF's own geodetic coordinates.
	case grs80

	/// The equatorial radius, a.
	public var equatorialRadius: Distance { earthEquatorialRadius }

	/// The flattening, f = (a - b) / a, where b is the polar radius.
	public var flattening: Double {
		switch self {
		case .wgs84: 1 / 298.257_223_563
		case .grs80: 1 / 298.257_222_101
		}
	}
}

extension Ellipsoid {
	/// Returns the geocentric position of a point given by geodetic coordinates, following
	/// `eraGd2gce` of ERFA.
	///
	/// - Parameters:
	///   - latitude: The geodetic latitude, in radians, in the closed interval [-π/2, π/2].
	///   - longitude: The longitude, in radians, positive east.
	///   - height: The height above the ellipsoid, in au.
	/// - Returns: The position in the ITRS, in au.
	func geocentric(latitude: Double, longitude: Double, height: Double) -> Vector3 {
		let a = equatorialRadius.astronomicalUnits
		let (sinPhi, cosPhi) = Math.sincos(latitude)
		let (sinLambda, cosLambda) = Math.sincos(longitude)
		let w = (1 - flattening) * (1 - flattening)
		let ac = a / (cosPhi * cosPhi + w * sinPhi * sinPhi).squareRoot()
		let r = (ac + height) * cosPhi
		return Vector3(r * cosLambda, r * sinLambda, (w * ac + height) * sinPhi)
	}

	/// Returns the geodetic coordinates of a geocentric position, following `eraGc2gde` of
	/// ERFA, which is exact to well under a millimeter for points near the Earth's surface.
	///
	/// - Parameter position: The position in the ITRS, in au.
	/// - Returns: The geodetic latitude and longitude, in radians, and the height above the
	///   ellipsoid, in au.
	func geodetic(_ position: Vector3) -> (latitude: Double, longitude: Double, height: Double) {
		let a = equatorialRadius.astronomicalUnits
		let f = flattening
		let e2 = (2 - f) * f
		let e4t = e2 * e2 * 1.5
		let ec2 = 1 - e2
		let ec = ec2.squareRoot()
		let p2 = position.x * position.x + position.y * position.y
		let longitude = p2 > 0 ? Math.atan2(position.y, position.x) : 0
		let absZ = abs(position.z)
		var latitude: Double
		let height: Double
		if p2 > a * a * 1e-32 {
			let p = p2.squareRoot()
			let s0 = absZ / a
			let pn = p / a
			let zc = ec * s0
			// Newton correction factors
			let c0 = ec * pn
			let c02 = c0 * c0
			let c03 = c02 * c0
			let s02 = s0 * s0
			let s03 = s02 * s0
			let a02 = c02 + s02
			let a0 = a02.squareRoot()
			let a03 = a02 * a0
			let d0 = zc * a03 + e2 * s03
			let f0 = pn * a03 - e2 * c03
			// Halley correction factor
			let b0 = e4t * s02 * c02 * pn * (a0 - ec)
			let s1 = d0 * f0 - b0 * s0
			let cc = ec * (f0 * f0 - b0 * c0)
			latitude = Math.atan(s1 / cc)
			let s12 = s1 * s1
			let cc2 = cc * cc
			height = (p * cc + absZ * s1 - a * (ec2 * s12 + cc2).squareRoot()) / (s12 + cc2).squareRoot()
		} else {
			// At a pole
			latitude = halfPi
			height = absZ - a * ec
		}
		if position.z < 0 {
			latitude = -latitude
		}
		return (latitude, longitude, height)
	}
}
