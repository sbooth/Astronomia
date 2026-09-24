//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// A celestial body.
public enum CelestialBody {
	/// Sol.
	case sun
	/// Luna.
	case moon
	/// Mercury.
	case mercury
	/// Venus.
	case venus
	/// Earth.
	case earth
	/// Mars.
	case mars
	/// Jupiter.
	case jupiter
	/// Saturn.
	case saturn
	/// Uranus.
	case uranus
	/// Neptune.
	case neptune
	/// Pluto.
	case pluto
	/// Earth/Moon barycenter.
	case earthMoonBarycenter
	/// Solar System barycenter.
	case solarSystemBarycenter
}

extension CelestialBody {
	/// Calculates and returns the body's heliocentric Cartesian coordinates in the J2000 equatorial system.
	///
	/// The position is not corrected for light travel time or aberration.
	/// - parameter date: The date and time for which to calculate the position.
	/// - returns: The heliocentric position vector of the center of the body.
	func heliocentricVector(_ date: Date = Date()) throws -> Vector {
		let vec = Astronomy_HelioVector(self.toAstroBody(), date.toAstroTime())
		guard vec.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: vec.status)
		}
		return vec.toVector()
	}

	/// Calculates and returns the body's geocentric Cartesian coordinates in the J2000 equatorial system.
	///
	/// This function corrects for light travel time.
	/// - parameter date: The date and time for which to calculate the position.
	/// - parameter correctForAberration: Whether to correct for aberration.
	/// - returns: The geocentric position vector of the center of the body.
	func geocentricVector(_ date: Date = Date(), correctForAberration: Bool = true) throws -> Vector {
		let aberration = correctForAberration ? ABERRATION : NO_ABERRATION
		let vec = Astronomy_GeoVector(self.toAstroBody(), date.toAstroTime(), aberration)
		guard vec.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: vec.status)
		}
		return vec.toVector()
	}
}

extension CelestialBody {
	/// Converts `self` to an `astro_body_t` instance.
	func toAstroBody() -> astro_body_t {
		switch self {
		case .sun:
			return BODY_SUN
		case .moon:
			return BODY_MOON
		case .mercury:
			return BODY_MERCURY
		case .venus:
			return BODY_VENUS
		case .earth:
			return BODY_EARTH
		case .mars:
			return BODY_MARS
		case .jupiter:
			return BODY_JUPITER
		case .saturn:
			return BODY_SATURN
		case .uranus:
			return BODY_URANUS
		case .neptune:
			return BODY_NEPTUNE
		case .pluto:
			return BODY_PLUTO
		case .earthMoonBarycenter:
			return BODY_EMB
		case .solarSystemBarycenter:
			return BODY_SSB
		}
	}
}
