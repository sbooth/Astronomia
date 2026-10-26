//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A body of a ``GeocentricEphemeris``, with its physical properties.
///
/// A body's radius is its own, not its ephemeris's, so an ephemeris that gives the bodies of
/// another, as one that wraps it, has their radii too. The radius gives the semidiameter of the
/// Sun and the Moon when they rise and set and in the local circumstances of eclipses, and
/// an ``Observation``'s `semidiameter(of:)`.
///
/// ```swift
/// enum Body: EphemerisBody {
/// 	case solarSystemBarycenter, sun, earth, moon
///
/// 	var radius: Distance? {
/// 		switch self {
/// 		case .solarSystemBarycenter: nil
/// 		case .sun: .kilometers(695_700)
/// 		case .earth: .kilometers(6_378.137)
/// 		case .moon: .kilometers(1_737.4)
/// 		}
/// 	}
/// }
/// ```
public protocol EphemerisBody: Hashable, Sendable {
	/// The body's equatorial radius, or `nil` for a point, such as a barycenter.
	var radius: Distance? { get }
}
