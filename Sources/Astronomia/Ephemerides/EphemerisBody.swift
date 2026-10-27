//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A body of a ``GeocentricEphemeris``, with its NAIF ID and its physical properties.
///
/// A body's radius is its own, not its ephemeris's, so an ephemeris that gives the bodies of
/// another, as one that wraps it, has their radii too. The radius gives the semidiameter of the
/// Sun and the Moon when they rise and set and in the local circumstances of eclipses, and
/// an ``Observation``'s `semidiameter(of:)`.
///
/// The NAIF ID is the body's number in JPL's ephemerides and SPICE, which names the same body
/// in different ephemerides: 0 for the solar system barycenter, 1 to 9 for the barycenters of
/// the planets' systems, 10 for the Sun, 199, 299, 399, and so on for the planets, and 301 for
/// the Moon.
///
/// ```swift
/// enum Body: EphemerisBody {
/// 	case solarSystemBarycenter, sun, earth, moon
///
/// 	var naifID: Int? {
/// 		switch self {
/// 		case .solarSystemBarycenter: 0
/// 		case .sun: 10
/// 		case .earth: 399
/// 		case .moon: 301
/// 		}
/// 	}
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
	/// The body's NAIF ID, or `nil` if it has none.
	var naifID: Int? { get }
	/// The body's equatorial radius, or `nil` for a point, such as a barycenter.
	var radius: Distance? { get }
}
