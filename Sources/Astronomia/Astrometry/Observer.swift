//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The place from which bodies are observed.
///
/// ```swift
/// let observer = Observer.geocenter
/// let mars = try observer.apparentPlace(of: .mars, at: instant)
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
	/// Returns the place of a body corrected for light time.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - ephemeris: The ephemeris of the body and the Earth.
	/// - Returns: The astrometric place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant, or the
	///     earlier instant at which the light left the body.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity that is
	///     NaN, infinite, or too large for the light time to be represented.
	public func astrometricPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		let (tt, geometry, _) = try observe(body, at: instant, context: context, ephemeris: ephemeris)
		let position = Position<ICRS>(geometry.target - geometry.observer.position)
		let lightTime: DayInterval
		do throws(DayIntervalError) {
			lightTime = try DayInterval(days: geometry.lightTime)
		} catch {
			throw .invalidState
		}
		return AstrometricPlace(position: position, lightTime: lightTime, instant: tt)
	}

	/// Returns the place where a body appears: corrected for light time, the gravitational
	/// deflection of light by the ephemeris's light-deflecting bodies, and aberration.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The apparent place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant, or the
	///     earlier instant at which the light left the body.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a position or velocity that is
	///     NaN, infinite, or too large for the light time to be represented.
	public func apparentPlace<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(EphemerisError) -> ApparentPlace<ICRS> {
		let (tt, geometry, positions) = try observe(body, at: instant, context: context, ephemeris: ephemeris)
		let relative = geometry.target - geometry.observer.position
		let distance = relative.length
		guard distance > 0 else {
			return ApparentPlace(position: .origin, lightTime: .zero, instant: tt)
		}
		let deflected = try Astrometry.deflected(relative / distance, geometry: geometry, of: body, positions: positions)
		let sunGravitationalParameter = E.lightDeflectingBodies.first { $0.body == E.sun }?.gravitationalParameter ?? 0
		let apparent = Astrometry.aberrated(deflected, velocity: geometry.observer.velocity, sunDistance: (geometry.observer.position - positions.sun.position).length, sunGravitationalParameter: sunGravitationalParameter)
		let lightTime: DayInterval
		do throws(DayIntervalError) {
			lightTime = try DayInterval(days: geometry.lightTime)
		} catch {
			throw .invalidState
		}
		return ApparentPlace(position: Position(apparent * distance), lightTime: lightTime, instant: tt)
	}

	/// Returns the place of a body of the built-in ephemeris corrected for light time.
	///
	/// - Parameters:
	///   - body: The body.
	///   - instant: The instant of observation.
	///   - context: Observational data for converting `instant` to TT and TDB.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws: An ``EphemerisError``, as ``astrometricPlace(of:at:context:ephemeris:)`` does.
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
	/// - Throws: An ``EphemerisError``, as ``apparentPlace(of:at:context:ephemeris:)`` does.
	public func apparentPlace<Scale: Timescale>(of body: SolarSystemEphemeris.Body, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(EphemerisError) -> ApparentPlace<ICRS> {
		try apparentPlace(of: body, at: instant, context: context, ephemeris: SolarSystemEphemeris())
	}
}

extension Observer {
	/// Returns the instant of observation in TT, the geometry of the observation, and the
	/// positions of the ephemeris.
	func observe<E: GeocentricEphemeris, Scale: Timescale>(_ body: E.Body, at instant: Instant<Scale>, context: Scale.Context, ephemeris: E) throws(EphemerisError) -> (Instant<TT>, Astrometry.Geometry, Astrometry.Positions<E>) {
		let tt: Instant<TT>
		do throws(TimescaleConversionError) {
			tt = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let positions = try Astrometry.Positions(ephemeris: ephemeris, at: Self.tdb(instant, context: context))
		let observer: (position: Vector3, velocity: Vector3)
		switch location {
		case .geocenter:
			observer = try positions.state(of: E.earth)
		}
		return (tt, try Astrometry.geometry(of: body, observer: observer, positions: positions), positions)
	}

	/// Returns an instant in TDB.
	static func tdb<Scale: Timescale>(_ instant: Instant<Scale>, context: Scale.Context) throws(EphemerisError) -> Instant<TDB> {
		do throws(TimescaleConversionError) {
			return try instant.converted(to: TDB.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
	}
}
