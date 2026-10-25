//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Observer {
	/// Returns the risings, settings, and transits of a body in an interval, in order.
	///
	/// Each event's instant is found to 0.1 s from the body's apparent place seen from the site:
	/// rising and setting when it crosses the event altitude, upper and lower transit when its
	/// hour angle is 0° and 180°. A body that never rises or never sets in the interval has only
	/// transits.
	///
	/// ```swift
	/// let site = try Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005))
	/// let events = try site.riseTransitSetEvents(of: .moon, from: start, to: end)
	/// let dawn = try site.riseTransitSetEvents(
	/// 	of: .sun, from: start, to: end, altitude: .civilTwilight)
	/// ```
	///
	/// The search places the body at hourly samples and at each step toward an event, about 40
	/// places for a day: about 40 ms at ``Precision/arcsecond``, the default of the method with
	/// the built-in ephemeris, whose 1" error moves an event by under 0.1 s at middle latitudes.
	/// A body that rises and sets again within an hour, grazing the event altitude near its
	/// transit, as can happen near the poles, may be missed.
	///
	/// - Parameters:
	///   - body: The body.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``,
	///     which takes the upper limb of a body with a radius in the ephemeris.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The events, in order of their instants.
	/// - Throws:
	///   - ``RiseTransitSetError/noHorizon`` if the observer is at the center of the Earth.
	///   - ``RiseTransitSetError/invalidInterval`` if `end` is before `start`.
	///   - ``RiseTransitSetError/timescaleConversion(_:)`` if the interval can't be converted to
	///     TT.
	///   - ``RiseTransitSetError/ephemeris(_:)`` if a place in the interval fails, as the places of
	///     an ``Observation`` do.
	public func riseTransitSetEvents<E: GeocentricEphemeris, Scale: Timescale>(of body: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius ?? E.radius(of: body)
		case .center: nil
		}
		return try riseTransitSetEvents(from: start, to: end, context: context, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
			do throws(EphemerisError) {
				return try observation.apparentPlace(of: body)
			} catch {
				throw .ephemeris(error)
			}
		}
	}

	/// Returns the risings, settings, and transits of a body of the built-in ephemeris in an
	/// interval, in order.
	///
	/// - Parameters:
	///   - body: The body.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - precision: The precision of the ephemeris, by default ``Precision/arcsecond``.
	/// - Returns: The events, in order of their instants.
	/// - Throws: A ``RiseTransitSetError``, as the method taking an ephemeris does.
	public func riseTransitSetEvents<Scale: Timescale>(of body: BuiltInEphemeris.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .arcsecond) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		try riseTransitSetEvents(of: body, from: start, to: end, context: context, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the risings, settings, and transits of a star in an interval, in order.
	///
	/// The star is a point: ``EventAltitude/standard`` takes it at -34'.
	///
	/// - Parameters:
	///   - star: The star.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - ephemeris: The ephemeris of the Earth and the light-deflecting bodies.
	/// - Returns: The events, in order of their instants.
	/// - Throws: A ``RiseTransitSetError``, as for a body, or
	///   ``RiseTransitSetError/star(_:)`` if the star can't be observed at an instant in the
	///   interval.
	public func riseTransitSetEvents<E: GeocentricEphemeris, Scale: Timescale>(of star: Star, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius
		case .center: nil
		}
		return try riseTransitSetEvents(from: start, to: end, context: context, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
			do throws(StarError) {
				return try observation.apparentPlace(of: star)
			} catch {
				throw .star(error)
			}
		}
	}

	/// Returns the risings, settings, and transits of a star in an interval, in order, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - star: The star.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - precision: The precision of the ephemeris, by default ``Precision/arcsecond``.
	/// - Returns: The events, in order of their instants.
	/// - Throws: A ``RiseTransitSetError``, as the method taking an ephemeris does.
	public func riseTransitSetEvents<Scale: Timescale>(of star: Star, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .arcsecond) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		try riseTransitSetEvents(of: star, from: start, to: end, context: context, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}

extension Observer {
	/// Returns the events of a target in an interval.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - altitude: The altitude of rising and setting.
	///   - radius: The radius of the target whose upper limb rises and sets, or `nil` for its
	///     center.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris.
	///   - place: Returns the target's apparent place from an observation.
	func riseTransitSetEvents<E: GeocentricEphemeris, Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, altitude: EventAltitude, radius: Distance?, earthOrientation: EarthOrientation, ephemeris: E, place: @escaping (Observation<E>) throws(RiseTransitSetError) -> ApparentPlace<ICRS>) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		guard case .site = location else {
			throw .noHorizon
		}
		let startTT: Instant<TT>
		let endTT: Instant<TT>
		do throws(TimescaleConversionError) {
			startTT = try start.converted(to: TT.self, sourceContext: context)
			endTT = try end.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		guard startTT <= endTT else {
			throw .invalidInterval
		}
		let origin = startTT.julianDate
		let length = endTT.julianDate.daysSinceJ2000 - origin.daysSinceJ2000
		/// Returns the instant some days after the start, within the interval.
		func instant(_ days: Double) throws(RiseTransitSetError) -> Instant<TT> {
			if days >= length {
				return endTT
			}
			do throws(JulianDateError) {
				return Instant<TT>(try origin.adding(days: days))
			} catch {
				// A time between two representable instants is representable.
				throw .invalidInterval
			}
		}

		let observer = self
		let search = RiseTransitSetSearch(length: length, evaluate: { (days: Double) throws(RiseTransitSetError) -> RiseTransitSetSearch.Sample in
			let tt = try instant(days)
			let observation: Observation<E>
			do throws(EphemerisError) {
				observation = try Observation(observer: observer, instant: tt, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris)
			} catch {
				throw .ephemeris(error)
			}
			let apparent = try place(observation)
			let observed: ObservedPlace
			do throws(ObserverError) {
				observed = try observation.observedPlace(of: apparent)
			} catch {
				// The observer is a site, and a place seen from it is never at the origin.
				throw .noHorizon
			}
			var reference = observed.altitude.radians
			if let radius {
				reference += Math.asin(min(radius.astronomicalUnits / observed.distance.astronomicalUnits, 1))
			}
			return RiseTransitSetSearch.Sample(time: days, instant: tt, hourAngle: observed.hourAngle.radians, height: reference - altitude.altitude.radians, place: observed)
		})
		return try search.events()
	}
}

extension Observer {
	/// Returns the first rising, setting, or transit of a body after an instant.
	///
	/// ```swift
	/// let sunrise = try site.nextRiseTransitSetEvent(.rise, of: .sun, after: instant)
	/// ```
	///
	/// The search covers half a day at a time, as `riseTransitSetEvents(of:from:to:)` does, and
	/// stops at the first event of the kind, so it evaluates the ephemeris no further than it
	/// needs to. An event within 0.5 s of the instant, as when the instant is an event
	/// found earlier, is taken as at it, not after it.
	///
	/// - Parameters:
	///   - kind: The kind of event.
	///   - body: The body.
	///   - instant: The instant to search from.
	///   - limit: How far after `instant` to search, by default 2 days, which holds the next
	///     event of each kind at an ordinary latitude. Near the poles, where a body can stay up
	///     or down for months, a longer limit finds it.
	///   - context: Observational data for converting `instant` to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``,
	///     which takes the upper limb of a body with a radius in the ephemeris.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - ephemeris: The ephemeris of the body, the Earth, and the light-deflecting bodies.
	/// - Returns: The event.
	/// - Throws:
	///   - ``RiseTransitSetError/noHorizon`` if the observer is at the center of the Earth.
	///   - ``RiseTransitSetError/invalidInterval`` if `limit` is negative, or the end of the
	///     search can't be represented.
	///   - ``RiseTransitSetError/timescaleConversion(_:)`` if `instant` can't be converted to
	///     TT.
	///   - ``RiseTransitSetError/ephemeris(_:)`` if a place fails, as the places of an
	///     ``Observation`` do.
	///   - ``RiseTransitSetError/eventNotFound`` if there is no event of the kind within
	///     `limit` after `instant`.
	public func nextRiseTransitSetEvent<E: GeocentricEphemeris, Scale: Timescale>(_ kind: RiseTransitSetEvent.Kind, of body: E.Body, after instant: Instant<Scale>, within limit: DayInterval = .days(2), context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(RiseTransitSetError) -> RiseTransitSetEvent {
		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius ?? E.radius(of: body)
		case .center: nil
		}
		return try nextRiseTransitSetEvent(kind, after: instant, within: limit, context: context, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
			do throws(EphemerisError) {
				return try observation.apparentPlace(of: body)
			} catch {
				throw .ephemeris(error)
			}
		}
	}

	/// Returns the first rising, setting, or transit of a body of the built-in ephemeris after
	/// an instant.
	///
	/// - Parameters:
	///   - kind: The kind of event.
	///   - body: The body.
	///   - instant: The instant to search from.
	///   - limit: How far after `instant` to search, by default 2 days.
	///   - context: Observational data for converting `instant` to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - precision: The precision of the ephemeris, by default ``Precision/arcsecond``.
	/// - Returns: The event.
	/// - Throws: A ``RiseTransitSetError``, as the method taking an ephemeris does.
	public func nextRiseTransitSetEvent<Scale: Timescale>(_ kind: RiseTransitSetEvent.Kind, of body: BuiltInEphemeris.Body, after instant: Instant<Scale>, within limit: DayInterval = .days(2), context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .arcsecond) throws(RiseTransitSetError) -> RiseTransitSetEvent {
		try nextRiseTransitSetEvent(kind, of: body, after: instant, within: limit, context: context, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first rising, setting, or transit of a star after an instant.
	///
	/// The star is a point: ``EventAltitude/standard`` takes it at -34'.
	///
	/// - Parameters:
	///   - kind: The kind of event.
	///   - star: The star.
	///   - instant: The instant to search from.
	///   - limit: How far after `instant` to search, by default 2 days. A star that never rises
	///     or sets at the site still transits each day.
	///   - context: Observational data for converting `instant` to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - ephemeris: The ephemeris of the Earth and the light-deflecting bodies.
	/// - Returns: The event.
	/// - Throws: A ``RiseTransitSetError``, as for a body, or
	///   ``RiseTransitSetError/star(_:)`` if the star can't be observed at an instant searched.
	public func nextRiseTransitSetEvent<E: GeocentricEphemeris, Scale: Timescale>(_ kind: RiseTransitSetEvent.Kind, of star: Star, after instant: Instant<Scale>, within limit: DayInterval = .days(2), context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(RiseTransitSetError) -> RiseTransitSetEvent {
		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius
		case .center: nil
		}
		return try nextRiseTransitSetEvent(kind, after: instant, within: limit, context: context, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
			do throws(StarError) {
				return try observation.apparentPlace(of: star)
			} catch {
				throw .star(error)
			}
		}
	}

	/// Returns the first rising, setting, or transit of a star after an instant, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - kind: The kind of event.
	///   - star: The star.
	///   - instant: The instant to search from.
	///   - limit: How far after `instant` to search, by default 2 days.
	///   - context: Observational data for converting `instant` to TT.
	///   - altitude: The altitude of rising and setting, by default ``EventAltitude/standard``.
	///   - earthOrientation: Observed Earth orientation, which places the site.
	///   - precision: The precision of the ephemeris, by default ``Precision/arcsecond``.
	/// - Returns: The event.
	/// - Throws: A ``RiseTransitSetError``, as the method taking an ephemeris does.
	public func nextRiseTransitSetEvent<Scale: Timescale>(_ kind: RiseTransitSetEvent.Kind, of star: Star, after instant: Instant<Scale>, within limit: DayInterval = .days(2), context: Scale.Context = Scale.defaultContext, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .arcsecond) throws(RiseTransitSetError) -> RiseTransitSetEvent {
		try nextRiseTransitSetEvent(kind, of: star, after: instant, within: limit, context: context, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}

extension Observer {
	/// The span of each search for the next event, half a day, in days.
	static var nextEventSpan: Double { 0.5 }

	/// Returns the first event of a kind of a target after an instant.
	///
	/// - Parameters:
	///   - kind: The kind of event.
	///   - instant: The instant to search from.
	///   - limit: How far after `instant` to search.
	///   - context: Observational data for converting `instant` to TT.
	///   - altitude: The altitude of rising and setting.
	///   - radius: The radius of the target whose upper limb rises and sets, or `nil` for its
	///     center.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris.
	///   - place: Returns the target's apparent place from an observation.
	func nextRiseTransitSetEvent<E: GeocentricEphemeris, Scale: Timescale>(_ kind: RiseTransitSetEvent.Kind, after instant: Instant<Scale>, within limit: DayInterval, context: Scale.Context, altitude: EventAltitude, radius: Distance?, earthOrientation: EarthOrientation, ephemeris: E, place: @escaping (Observation<E>) throws(RiseTransitSetError) -> ApparentPlace<ICRS>) throws(RiseTransitSetError) -> RiseTransitSetEvent {
		guard case .site = location else {
			throw .noHorizon
		}
		guard limit.inDays >= 0 else {
			throw .invalidInterval
		}
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let end: Instant<TT>
		do throws(JulianDateError) {
			end = Instant(try start.julianDate.adding(limit))
		} catch {
			throw .invalidInterval
		}
		// Half a day at a time, so the search stops soon after the event
		var from = start
		while from < end {
			var to = end
			do throws(JulianDateError) {
				let next = Instant<TT>(try from.julianDate.adding(days: Self.nextEventSpan))
				to = min(next, end)
			} catch {
				throw .invalidInterval
			}
			let events = try riseTransitSetEvents(from: from, to: to, context: TT.defaultContext, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris, place: place)
			// An event within 0.5 s of the instant, as when the instant is an event found
			// earlier and found again a little after it, is taken as at it.
			if let event = events.first(where: { $0.kind == kind && ($0.instant.julianDate.daysSinceJ2000 - start.julianDate.daysSinceJ2000) * secondsPerDay > 0.5 }) {
				return event
			}
			from = to
		}
		throw .eventNotFound
	}
}
