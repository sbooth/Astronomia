//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The place from which bodies and stars are observed: the center of the Earth, or a site on
/// its surface.
///
/// ```swift
/// let observer = Observer.geocenter
/// let mars = try observer.apparentPlace(of: .mars, at: instant)
///
/// let greenwich = try Observer.site(
/// 	latitude: .degrees(51.4769),
/// 	longitude: .degrees(-0.0005),
/// 	height: .meters(46))
/// let moon = try greenwich.apparentPlace(of: .moon, at: instant)
/// ```
///
/// A place seen from a site differs from the geocentric place by the diurnal parallax, up to
/// about 1° for the Moon, and by the diurnal aberration, up to 0.32", from the site's motion as
/// the Earth turns. Light grazing the Earth is also deflected by its gravity, by up to 0.57 mas.
///
/// Each place evaluates the ephemeris for the observer and the light-deflecting bodies at the
/// instant. For several places at one instant, and for places of stars, create an
/// ``Observation`` once and take the places from it:
///
/// ```swift
/// let sky = try Observer.geocenter.observation(at: instant)
/// let sirius = try sky.apparentPlace(of: star)
/// ```
public struct Observer: Hashable, Sendable {
	/// Where the observer is.
	enum Location: Hashable, Sendable {
		/// The center of the Earth.
		case geocenter
		/// A site fixed to the Earth, at a position in the ITRS, in au, with the geodetic
		/// latitude and longitude, in radians, whose ellipsoid normal gives its horizon.
		case site(Vector3, latitude: Double, longitude: Double)
	}

	/// Where the observer is.
	let location: Location

	/// An observer at the center of the Earth.
	public static let geocenter = Observer(location: .geocenter)

	/// The greatest height of a site above or below the ellipsoid, 100 km.
	static let maximumHeight = Distance.kilometers(100)

	/// Returns an observer at a site given by its geodetic coordinates.
	///
	/// - Parameters:
	///   - latitude: The geodetic latitude, positive north.
	///   - longitude: The longitude, positive east.
	///   - height: The height above the ellipsoid. A GPS receiver gives this height; a height
	///     above mean sea level differs from it by the geoid's height, up to about 100 m.
	///   - ellipsoid: The ellipsoid the coordinates are on.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidLatitude`` if the latitude is outside [-90°, 90°].
	///   - ``ObserverError/invalidHeight`` if the height is more than 100 km above or below
	///     the ellipsoid.
	public static func site(latitude: Angle, longitude: Angle, height: Distance = .zero, ellipsoid: Ellipsoid = .wgs84) throws(ObserverError) -> Observer {
		guard latitude.radians.isFinite, longitude.radians.isFinite, height.astronomicalUnits.isFinite else {
			throw .nonFiniteValue
		}
		guard abs(latitude.radians) <= halfPi else {
			throw .invalidLatitude
		}
		guard height.magnitude <= maximumHeight else {
			throw .invalidHeight
		}
		let position = ellipsoid.geocentric(latitude: latitude.radians, longitude: longitude.radians, height: height.astronomicalUnits)
		return Observer(location: .site(position, latitude: latitude.radians, longitude: longitude.radians))
	}

	/// Returns an observer at a site given by its position in the ITRS.
	///
	/// - Parameter position: The position of the site.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidHeight`` if the position is more than 100 km above or below
	///     the WGS84 ellipsoid.
	public static func site(_ position: Position<ITRS>) throws(ObserverError) -> Observer {
		let vector = position.vector
		guard vector.x.isFinite, vector.y.isFinite, vector.z.isFinite else {
			throw .nonFiniteValue
		}
		let geodetic = Ellipsoid.wgs84.geodetic(vector)
		// A micrometer's allowance for the rounding of a site's coordinates through the ITRS
		guard abs(geodetic.height) <= maximumHeight.astronomicalUnits + 1e-6 / metersPerAstronomicalUnit else {
			throw .invalidHeight
		}
		return Observer(location: .site(vector, latitude: geodetic.latitude, longitude: geodetic.longitude))
	}

	/// The position of the site in the ITRS, or `nil` for an observer at the center of the
	/// Earth.
	public var position: Position<ITRS>? {
		switch location {
		case .geocenter: nil
		case let .site(position, _, _): Position(position)
		}
	}
}

extension Observer {
	/// Returns an observation at an instant, from which the places of any number of bodies and
	/// stars are found.
	///
	/// - Parameters:
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	///   - ephemeris: The ephemeris of the Earth, the Sun, the light-deflecting bodies, and the
	///     bodies to observe.
	/// - Returns: The observation.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted to TT
	///     and TDB, or for a site, to UT1 with the context of `earthOrientation`.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity of the
	///     observer, the Sun, or a light-deflecting body that is NaN or infinite or as fast as
	///     light, an observer more than 10,000 au from the solar system barycenter, or an
	///     observer within a light-deflecting body other than the Earth.
	public func observation<E: GeocentricEphemeris, Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(EphemerisError) -> Observation<E> {
		try Observation(observer: self, instant: instant, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris)
	}

	/// Returns an observation at an instant with the built-in ephemeris.
	///
	/// - Parameters:
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	/// - Returns: The observation.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func observation<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(EphemerisError) -> Observation<BuiltInEphemeris> {
		try observation(at: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris())
	}
}

extension Observer {
	/// Returns the place of a body corrected for light time.
	///
	/// This is the astrometric place of the body from an observation at the instant.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The astrometric place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws: An ``EphemerisError`` from creating the observation or from the place.
	public func astrometricPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		try observation(at: instant, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris).astrometricPlace(of: body)
	}

	/// Returns the place where a body appears: corrected for light time, the gravitational
	/// deflection of light by the ephemeris's light-deflecting bodies, and aberration.
	///
	/// This is the apparent place of the body from an observation at the instant.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The apparent place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws: An ``EphemerisError`` from creating the observation or from the place.
	public func apparentPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try observation(at: instant, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris).apparentPlace(of: body)
	}

	/// Returns the place of a body of the built-in ephemeris corrected for light time.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func astrometricPlace<Scale: Timescale>(of body: BuiltInEphemeris.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		try astrometricPlace(of: body, at: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris())
	}

	/// Returns the place where a body of the built-in ephemeris appears.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - earthOrientation: Observed Earth orientation, which places a site at the instant; it
	///     has no effect for an observer at the center of the Earth.
	/// - Returns: The apparent place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func apparentPlace<Scale: Timescale>(of body: BuiltInEphemeris.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try apparentPlace(of: body, at: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris())
	}
}
