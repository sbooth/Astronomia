//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Where a body or a star is seen in the sky of a site on the Earth: its azimuth and altitude,
/// and its hour angle and declination, corrected for refraction if the atmosphere is given.
///
/// An observed place is the topocentric ``ApparentPlace`` turned with the Earth to the site's
/// horizon, following `eraAtioq` of ERFA. The horizon is the plane perpendicular to the
/// normal to the ellipsoid at the site: the one its geodetic coordinates are on, or WGS84 for
/// a site given by its ITRS position. A plumb line follows the normal to within the deflection
/// of the vertical, typically a few arcseconds and up to about 1′ in mountains.
///
/// The hour angle and declination are measured, as an equatorial mount fixed to the ground
/// measures them, from the pole of the ITRS and the site's meridian. They differ from the
/// apparent declination and the hour angle about the Earth's rotation axis by the polar
/// motion, up to about 0.5".
///
/// The parallactic angle is the angle at the target between the directions to the pole and to
/// the zenith, as `eraHd2pa` of ERFA finds it from the hour angle and declination: positive
/// west of the meridian, where the zenith is east of the north point of the target, and 0° or
/// 180° on the meridian. A position angle measured from the north point less the parallactic
/// angle is measured from the top of the target as the site sees it.
///
/// ```swift
/// let site = try Observer.site(latitude: .degrees(19.8207), longitude: .degrees(-155.4681))
/// let sky = try site.observation(at: instant)
/// let moon = try sky.observedPlace(of: sky.apparentPlace(of: .moon), conditions: conditions)
/// print(moon.azimuth.degrees, moon.altitude.degrees)
/// ```
public struct ObservedPlace: Hashable, Sendable {
	/// The azimuth, measured from north through east, in the right-open interval [0°, 360°).
	public let azimuth: Angle
	/// The altitude above the horizon, raised by refraction if the atmosphere is given.
	public let altitude: Angle
	/// The hour angle, measured west from the site's meridian, in the left-open interval
	/// (-180°, 180°].
	public let hourAngle: Angle
	/// The declination, from the site's equator.
	public let declination: Angle
	/// The angle at the target from the direction to the pole to the direction to the zenith,
	/// in the left-open interval (-180°, 180°].
	public let parallacticAngle: Angle
	/// The distance of the target when the light left it.
	public let distance: Distance
	/// The instant of observation.
	public let instant: Instant<TT>

	/// Creates an observed place.
	init(azimuth: Angle, altitude: Angle, hourAngle: Angle, declination: Angle, parallacticAngle: Angle, distance: Distance, instant: Instant<TT>) {
		self.azimuth = azimuth
		self.altitude = altitude
		self.hourAngle = hourAngle
		self.declination = declination
		self.parallacticAngle = parallacticAngle
		self.distance = distance
		self.instant = instant
	}

	/// The zenith distance, 90° less the altitude.
	public var zenithDistance: Angle {
		Angle(radians: halfPi - altitude.radians)
	}
}
