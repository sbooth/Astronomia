//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An observer at an instant, from which the places of any number of bodies and stars are
/// found.
///
/// Creating an observation evaluates the ephemeris for the observer, the Sun's barycentric
/// state, and the light-deflecting bodies, which is most of the cost of a place: about 19 ms
/// with the built-in ephemeris, or under a millisecond at a coarser ``SeriesPrecision`` of it. For
/// a site on the Earth it also places the site in the GCRS with the observation's
/// ``earthOrientation``, at the cost of a precession-nutation, and the Earth then deflects light
/// from above the site's horizon. A place of a star then takes well under a microsecond, and a
/// place of a body evaluates only the body itself, twice.
///
/// ```swift
/// let sky = try Observer.geocenter.observation(at: instant)
/// let places = try catalog.map { try sky.apparentPlace(of: $0) }
/// let mars = try sky.apparentPlace(of: .mars)
/// ```
///
/// From a site, ``observedPlace(of:conditions:)`` turns an apparent place to the site's
/// horizon, as azimuth and altitude, and hour angle and declination, with refraction.
///
/// The states of the observer, the Sun, and the light-deflecting bodies are checked when the
/// observation is created. A place of a star then fails only if the star's own motion makes
/// it unobservable as a star at the instant.
public struct Observation<E: GeocentricEphemeris>: Sendable {
	/// The observer.
	public let observer: Observer
	/// The instant of observation, which is also the epoch of a frame of date.
	public let instant: Instant<TT>
	/// The observer's position and velocity relative to the solar system barycenter at the
	/// instant of observation.
	public let observerState: StateVector<ICRS>
	/// The observed Earth orientation applied: UT1, polar motion, and the celestial pole
	/// offsets, which place a site in the GCRS.
	public let earthOrientation: EarthOrientation

	/// The positions of the ephemeris.
	let positions: Astrometry.Positions<E>
	/// The observer's barycentric position and velocity.
	let observerVectors: (position: Vector3, velocity: Vector3)
	/// The site's horizon, or `nil` for an observer at the center of the Earth.
	let horizon: Horizon?
	/// The light-deflecting bodies at the instant of observation.
	let deflectors: [Astrometry.Deflector<E.Body>]
	/// The Sun's gravitational parameter, or 0 if the ephemeris doesn't list the Sun as a
	/// light-deflecting body.
	let sunGravitationalParameter: Double

	/// The greatest distance of an observer from the solar system barycenter, 10,000 au.
	///
	/// A ``Star`` is observed only while it is at least 20,600 au from the barycenter, so an
	/// observer within this distance is always well away from one.
	static var maximumObserverDistance: Double { 10_000 }

	/// Creates an observation, evaluating the ephemeris.
	///
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the instant.
	///   - ``EphemerisError/timescaleConversion(_:)`` if `instant` can't be converted, or UT1
	///     can't be found for a site.
	///   - ``EphemerisError/invalidState`` if a state is NaN or infinite or as fast as light,
	///     the observer is more than 10,000 au from the barycenter, or the observer is within a
	///     light-deflecting body other than the Earth.
	init<Scale: Timescale>(observer: Observer, instant: Instant<Scale>, context: Scale.Context, earthOrientation: EarthOrientation, ephemeris: E) throws(EphemerisError) {
		let tt: Instant<TT>
		let tdb: Instant<TDB>
		do throws(TimescaleConversionError) {
			tt = try instant.converted(to: TT.self, sourceContext: context)
			tdb = try instant.converted(to: TDB.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let positions = try Astrometry.Positions(ephemeris: ephemeris, at: tdb)
		let earth = try positions.state(of: E.earth)
		let state: (position: Vector3, velocity: Vector3)
		let horizon: Horizon?
		switch observer.location {
		case .geocenter:
			state = earth
			horizon = nil
		case let .site(site, latitude, longitude):
			let ut1: Instant<UT1>
			do throws(TimescaleConversionError) {
				ut1 = try instant.converted(to: UT1.self, sourceContext: context, targetContext: earthOrientation.ut1)
			} catch {
				throw .timescaleConversion(error)
			}
			// The site's geocentric position and velocity, with the Earth's rotation
			let toITRS = ICRS.rotation(to: ITRS.self, at: tt, ut1: ut1, earthOrientation: earthOrientation)
			let spin = ITRS.angularVelocity(at: tt, earthOrientation: earthOrientation)
			let geocentric = toITRS.inverse.uncheckedApply(to: StateVector<ITRS>(site, Vector3(0, 0, 0)), fromFrameTurningAt: spin)
			horizon = Horizon(toITRS: toITRS, latitude: latitude, longitude: longitude)
			state = try Astrometry.Positions<E>.validated(earth.position + geocentric.position.vector, earth.velocity + geocentric.velocity.vector)
		}
		guard state.position.length <= Self.maximumObserverDistance else {
			throw .invalidState
		}

		var deflectors: [Astrometry.Deflector<E.Body>] = []
		for body in E.lightDeflectingBodies {
			if body.body == E.earth {
				// At the Earth's center its gravity deflects nothing; on its surface it deflects
				// light from above the horizon.
				if case .site = observer.location {
					deflectors.append(Astrometry.Deflector(body: body.body, state: earth, gravitationalParameter: body.gravitationalParameter, radius: body.radius.astronomicalUnits, isObserversBody: true))
				}
				continue
			}
			let deflector = try positions.state(of: body.body)
			guard (state.position - deflector.position).length > body.radius.astronomicalUnits else {
				throw .invalidState
			}
			deflectors.append(Astrometry.Deflector(body: body.body, state: deflector, gravitationalParameter: body.gravitationalParameter, radius: body.radius.astronomicalUnits, isObserversBody: false))
		}

		self.observer = observer
		self.instant = tt
		self.earthOrientation = earthOrientation
		self.positions = positions
		self.observerVectors = state
		self.observerState = StateVector(state.position, state.velocity)
		self.horizon = horizon
		self.deflectors = deflectors
		self.sunGravitationalParameter = E.lightDeflectingBodies.first { $0.body == E.sun }?.gravitationalParameter ?? 0
	}
}

extension Observation {
	/// Returns the place of a body corrected for light time.
	///
	/// - Parameter body: The body.
	/// - Returns: The astrometric place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws:
	///   - ``EphemerisError/outsideCoverage`` if the ephemeris doesn't cover the earlier
	///     instant at which the light left the body.
	///   - ``EphemerisError/invalidState`` if the ephemeris gives a state of the body that is
	///     NaN or infinite or as fast as light, a position too far for the light time to be
	///     represented, or a motion so fast that the light time doesn't converge.
	public func astrometricPlace(of body: E.Body) throws(EphemerisError) -> AstrometricPlace<ICRS> {
		let geometry = try Astrometry.geometry(of: body, observer: observerVectors, positions: positions)
		let position = Position<ICRS>(geometry.target - geometry.observer.position)
		return AstrometricPlace(position: position, lightTime: try Self.interval(geometry.lightTime), instant: instant)
	}

	/// Returns the place where a body appears: corrected for light time, the gravitational
	/// deflection of light by the ephemeris's light-deflecting bodies, and aberration.
	///
	/// - Parameter body: The body.
	/// - Returns: The apparent place, in ICRS axes. For the observer's own body it is at the
	///   origin.
	/// - Throws: An ``EphemerisError``, as the astrometric place of a body does.
	public func apparentPlace(of body: E.Body) throws(EphemerisError) -> ApparentPlace<ICRS> {
		let geometry = try Astrometry.geometry(of: body, observer: observerVectors, positions: positions)
		let relative = geometry.target - geometry.observer.position
		let distance = relative.length
		guard distance > 0 else {
			return ApparentPlace(position: .origin, lightTime: .zero, instant: instant)
		}
		let apparent = apparentDirection(relative / distance, geometry: geometry, excluding: body)
		// Finite states can still meet in a degenerate geometry, such as a target at a
		// deflector's center.
		guard apparent.x.isFinite, apparent.y.isFinite, apparent.z.isFinite else {
			throw .invalidState
		}
		return ApparentPlace(position: Position(apparent * distance), lightTime: try Self.interval(geometry.lightTime), instant: instant)
	}

	/// Returns the place of a star corrected for its space motion and parallax.
	///
	/// The star is where it was when the light reaching the observer left it, which includes
	/// its motion over the light's extra travel across the solar system. The light time is the
	/// star's distance over the speed of light, which for a star without a parallax is that of
	/// its nominal distance of 1 Gpc (see ``Star``).
	///
	/// - Parameter star: The star.
	/// - Returns: The astrometric place, in ICRS axes.
	/// - Throws:
	///   - ``StarError/excessiveTimeSpan`` if the instant is more than 10 million Julian years
	///     from the star's epoch.
	///   - ``StarError/withinSolarSystem`` if at the instant the star's motion puts it within
	///     about 20,600 au of the barycenter.
	public func astrometricPlace(of star: Star) throws(StarError) -> AstrometricPlace<ICRS> {
		let geometry = try geometry(of: star)
		let position = Position<ICRS>(geometry.target - geometry.observer.position)
		return AstrometricPlace(position: position, lightTime: try Self.interval(lightTimeOfStar: geometry.lightTime), instant: instant)
	}

	/// Returns the place where a star appears: corrected for its space motion and parallax,
	/// the gravitational deflection of light by the ephemeris's light-deflecting bodies, and
	/// aberration.
	///
	/// - Parameter star: The star.
	/// - Returns: The apparent place, in ICRS axes.
	/// - Throws: A ``StarError``, as the astrometric place of a star does.
	public func apparentPlace(of star: Star) throws(StarError) -> ApparentPlace<ICRS> {
		let geometry = try geometry(of: star)
		let relative = geometry.target - geometry.observer.position
		let distance = relative.length
		let apparent = apparentDirection(relative / distance, geometry: geometry, excluding: nil)
		return ApparentPlace(position: Position(apparent * distance), lightTime: try Self.interval(lightTimeOfStar: geometry.lightTime), instant: instant)
	}
}

extension Observation {
	/// Returns the place of a body where it appears, in a frame of date at the instant of
	/// observation.
	///
	/// The place is the apparent place in ICRS axes converted with the observation's
	/// ``earthOrientation``: in ``TrueEquatorOfDate`` it gives the classical apparent right
	/// ascension and declination, and in ``CIRS`` the intermediate ones. Each call computes the
	/// frame's rotation, about 70 µs; for many places, compute the rotation once with
	/// ``FixedReferenceFrame/rotation(to:at:earthOrientation:)`` and apply it to each place's
	/// position with `*`.
	///
	/// - Parameters:
	///   - body: The body.
	///   - frame: The frame of date.
	/// - Returns: The apparent place in `frame`, whose epoch is the instant of observation.
	/// - Throws: An ``EphemerisError``, as the apparent place of a body does.
	public func apparentPlace<Frame: DatedReferenceFrame>(of body: E.Body, in frame: Frame.Type) throws(EphemerisError) -> ApparentPlace<Frame> {
		try apparentPlace(of: body).converted(to: frame, earthOrientation: earthOrientation)
	}

	/// Returns the place of a star where it appears, in a frame of date at the instant of
	/// observation.
	///
	/// The place is the apparent place in ICRS axes converted with the observation's
	/// ``earthOrientation``, as for a body.
	///
	/// - Parameters:
	///   - star: The star.
	///   - frame: The frame of date.
	/// - Returns: The apparent place in `frame`, whose epoch is the instant of observation.
	/// - Throws: A ``StarError``, as the apparent place of a star does.
	public func apparentPlace<Frame: DatedReferenceFrame>(of star: Star, in frame: Frame.Type) throws(StarError) -> ApparentPlace<Frame> {
		try apparentPlace(of: star).converted(to: frame, earthOrientation: earthOrientation)
	}

	/// Returns where an apparent place is seen in the sky of the observer's site: its azimuth
	/// and altitude, and its hour angle and declination, refracted by the atmosphere if it is
	/// given.
	///
	/// ```swift
	/// let sky = try site.observation(at: instant)
	/// let moon = try sky.observedPlace(of: sky.apparentPlace(of: .moon), conditions: conditions)
	/// ```
	///
	/// - Parameters:
	///   - place: An apparent place from this observation.
	///   - conditions: The atmosphere at the site, or `nil` for no refraction.
	/// - Returns: The observed place.
	/// - Throws:
	///   - ``ObserverError/noHorizon`` if the observer is at the center of the Earth.
	///   - ``ObserverError/placeMismatch`` if `place` can't be from this observation: it is at
	///     another instant, or it is at the origin, as only a geocentric place of the Earth
	///     is.
	public func observedPlace(of place: ApparentPlace<ICRS>, conditions: AtmosphericConditions? = nil) throws(ObserverError) -> ObservedPlace {
		guard let horizon else {
			throw .noHorizon
		}
		let vector = place.position.vector
		let distance = vector.length
		guard place.instant == instant, distance > 0 else {
			throw .placeMismatch
		}
		return horizon.observedPlace(of: vector / distance, refraction: conditions?.refractionConstants, distance: Distance(astronomicalUnits: distance), instant: instant)
	}
}

extension Observation {
	/// Returns the geometry of the observation of a star.
	///
	/// - Throws: A ``StarError``, as the astrometric place of a star does.
	func geometry(of star: Star) throws(StarError) -> Astrometry.Geometry {
		let (relative, lightTime) = try star.observed(daysSinceEpoch: Astrometry.days(from: star.epoch, to: positions.tdb), from: observerVectors.position)
		return Astrometry.Geometry(observer: observerVectors, target: observerVectors.position + relative, lightTime: lightTime)
	}

	/// Returns a direction deflected by the light-deflecting bodies and corrected for
	/// aberration.
	///
	/// - Parameters:
	///   - direction: The unit vector from the observer to the source.
	///   - geometry: The observation.
	///   - body: The target, or `nil` for a source outside the ephemeris.
	/// - Returns: The apparent unit vector.
	func apparentDirection(_ direction: Vector3, geometry: Astrometry.Geometry, excluding body: E.Body?) -> Vector3 {
		let deflected = Astrometry.deflected(direction, geometry: geometry, deflectors: deflectors, excluding: body)
		let sunDistance = (observerVectors.position - positions.sun.position).length
		return Astrometry.aberrated(deflected, velocity: observerVectors.velocity, sunDistance: sunDistance, sunGravitationalParameter: sunGravitationalParameter)
	}

	/// Returns the light time of a body as an interval.
	///
	/// - Throws: ``EphemerisError/invalidState`` if the light time can't be represented.
	static func interval(_ days: Double) throws(EphemerisError) -> DayInterval {
		do throws(DayIntervalError) {
			return try DayInterval(days: days)
		} catch {
			throw .invalidState
		}
	}

	/// Returns the light time of a star as an interval.
	///
	/// The time span limit keeps a star within 1 Gpc plus 10 million light years, so its light
	/// time is finite and far below the limits of an interval.
	///
	/// - Throws: ``StarError/excessiveTimeSpan`` if the light time can't be represented.
	static func interval(lightTimeOfStar days: Double) throws(StarError) -> DayInterval {
		do throws(DayIntervalError) {
			return try DayInterval(days: days)
		} catch {
			throw .excessiveTimeSpan
		}
	}
}
