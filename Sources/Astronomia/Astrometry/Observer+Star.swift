//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Observer {
	/// Returns the place of a star corrected for its space motion and parallax.
	///
	/// The star is where it was when the light reaching the observer left it, which includes
	/// its motion over the light's extra travel across the solar system. The light time is the
	/// star's distance over the speed of light, which for a star without a parallax is that of
	/// its nominal distance of 1 Gpc (see ``Star``).
	///
	/// - Parameters:
	///   - star: The star.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - ephemeris: The ephemeris of the Earth.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity of the
	///     Earth, the Sun, or a light-deflecting body that is NaN or infinite, a speed of light
	///     or more, or a position too far to observe from.
	public func astrometricPlace<E: GeocentricEphemeris, Scale: Timescale>(of star: Star, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		let (tt, geometry, _) = try observe(star, at: instant, context: context, ephemeris: ephemeris)
		let position = Position<ICRS>(geometry.target - geometry.observer.position)
		let lightTime: DayInterval
		do throws(DayIntervalError) {
			lightTime = try DayInterval(days: geometry.lightTime)
		} catch {
			throw .invalidState
		}
		return AstrometricPlace(position: position, lightTime: lightTime, instant: tt)
	}

	/// Returns the place where a star appears: corrected for its space motion and parallax,
	/// the gravitational deflection of light by the ephemeris's light-deflecting bodies, and
	/// aberration.
	///
	/// - Parameters:
	///   - star: The star.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - ephemeris: The ephemeris of the Earth and the light-deflecting bodies.
	/// - Returns: The apparent place, in ICRS axes.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity of the
	///     Earth, the Sun, or a light-deflecting body that is NaN or infinite, a speed of light
	///     or more, or a position too far to observe from.
	public func apparentPlace<E: GeocentricEphemeris, Scale: Timescale>(of star: Star, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> ApparentPlace<ICRS> {
		let (tt, geometry, positions) = try observe(star, at: instant, context: context, ephemeris: ephemeris)
		let relative = geometry.target - geometry.observer.position
		let distance = relative.length
		let deflected = try Astrometry.deflected(relative / distance, geometry: geometry, of: nil, positions: positions)
		let sunGravitationalParameter = E.lightDeflectingBodies.first { $0.body == E.sun }?.gravitationalParameter ?? 0
		let apparent = Astrometry.aberrated(deflected, velocity: geometry.observer.velocity, sunDistance: (geometry.observer.position - positions.sun.position).length, sunGravitationalParameter: sunGravitationalParameter)
		// Finite states can still meet in a degenerate geometry, such as an observer at the Sun.
		guard apparent.x.isFinite, apparent.y.isFinite, apparent.z.isFinite else {
			throw .invalidState
		}
		let lightTime: DayInterval
		do throws(DayIntervalError) {
			lightTime = try DayInterval(days: geometry.lightTime)
		} catch {
			throw .invalidState
		}
		return ApparentPlace(position: Position(apparent * distance), lightTime: lightTime, instant: tt)
	}

	/// Returns the place of a star corrected for its space motion and parallax, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - star: The star.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func astrometricPlace<Scale: Timescale>(of star: Star, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		try astrometricPlace(of: star, at: instant, context: context, ephemeris: SolarSystemEphemeris())
	}

	/// Returns the place where a star appears, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - star: The star.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The apparent place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as the method taking an ephemeris does.
	public func apparentPlace<Scale: Timescale>(of star: Star, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try apparentPlace(of: star, at: instant, context: context, ephemeris: SolarSystemEphemeris())
	}
}

extension Observer {
	/// Returns the instant of observation in TT, the geometry of the observation of a star, and
	/// the positions of the ephemeris.
	func observe<E: GeocentricEphemeris, Scale: Timescale>(_ star: Star, at instant: Instant<Scale>, context: Scale.Context, ephemeris: E) throws(EphemerisError) -> (Instant<TT>, Astrometry.Geometry, Astrometry.Positions<E>) {
		let tt: Instant<TT>
		do throws(TimescaleConversionError) {
			tt = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let tdb = try Self.tdb(instant, context: context)
		let positions = try Astrometry.Positions(ephemeris: ephemeris, at: tdb)
		let observer: (position: Vector3, velocity: Vector3)
		switch location {
		case .geocenter:
			observer = try positions.state(of: E.earth)
		}
		let (relative, lightTime) = star.observed(daysSinceEpoch: Astrometry.days(from: star.epoch, to: tdb), from: observer.position)
		return (tt, Astrometry.Geometry(observer: observer, target: observer.position + relative, lightTime: lightTime), positions)
	}
}
