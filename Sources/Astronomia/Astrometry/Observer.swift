//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The place from which bodies and stars are observed.
///
/// ```swift
/// let observer = Observer.geocenter
/// let mars = try observer.apparentPlace(of: .mars, at: instant)
/// ```
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
	}

	/// Where the observer is.
	let location: Location

	/// An observer at the center of the Earth.
	public static let geocenter = Observer(location: .geocenter)
}

extension Observer {
	/// Returns an observation at an instant, from which the places of any number of bodies and
	/// stars are found.
	///
	/// - Parameters:
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - ephemeris: The ephemeris of the Earth, the Sun, the light-deflecting bodies, and the
	///     bodies to observe.
	/// - Returns: The observation.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity of the
	///     observer, the Sun, or a light-deflecting body that is NaN or infinite or as fast as
	///     light, an observer more than 10,000 au from the solar system barycenter, or an
	///     observer within a light-deflecting body.
	public func observation<E: GeocentricEphemeris, Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> Observation<E> {
		try Observation(observer: self, instant: instant, context: context, ephemeris: ephemeris)
	}

	/// Returns an observation at an instant with the built-in ephemeris.
	///
	/// - Parameters:
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The observation.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func observation<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> Observation<SolarSystemEphemeris> {
		try observation(at: instant, context: context, ephemeris: SolarSystemEphemeris())
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
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The astrometric place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws: An ``EphemerisError`` from creating the observation or from the place.
	public func astrometricPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		try observation(at: instant, context: context, ephemeris: ephemeris).astrometricPlace(of: body)
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
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The apparent place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws: An ``EphemerisError`` from creating the observation or from the place.
	public func apparentPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try observation(at: instant, context: context, ephemeris: ephemeris).apparentPlace(of: body)
	}

	/// Returns the place of a body of the built-in ephemeris corrected for light time.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func astrometricPlace<Scale: Timescale>(of body: SolarSystemEphemeris.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		try astrometricPlace(of: body, at: instant, context: context, ephemeris: SolarSystemEphemeris())
	}

	/// Returns the place where a body of the built-in ephemeris appears.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The apparent place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func apparentPlace<Scale: Timescale>(of body: SolarSystemEphemeris.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try apparentPlace(of: body, at: instant, context: context, ephemeris: SolarSystemEphemeris())
	}
}
