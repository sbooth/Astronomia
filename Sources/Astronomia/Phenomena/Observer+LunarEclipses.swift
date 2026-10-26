//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Observer {
	/// Returns the local circumstances of an eclipse of the Moon at this site: the Moon's place
	/// at each contact, its rises and sets during the eclipse, and when it is up.
	///
	/// - Parameters:
	///   - eclipse: The eclipse.
	///   - moon: The Moon.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction. Whether the Moon is up is decided by `altitude` alone.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The local circumstances.
	/// - Throws:
	///   - ``Moon/EclipseError/noHorizon`` if the observer is the center of the Earth.
	///   - ``Moon/EclipseError/ephemeris(_:)`` if a place of the Moon fails, as for an
	///     ``Observation``, or UT1 can't be found.
	public func localCircumstances<E: GeocentricEphemeris>(of eclipse: Moon.Eclipse, moon: E.Body, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Moon.EclipseError) -> Moon.LocalEclipse {
		guard case .site = location else {
			throw .noHorizon
		}
		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius ?? moon.radius
		case .center: nil
		}
		/// Returns whether the Moon is up in an unrefracted place.
		func isUp(_ place: ObservedPlace) -> Bool {
			var reference = place.altitude.radians
			if let radius {
				reference += Math.asin(min(radius.astronomicalUnits / place.distance.astronomicalUnits, 1))
			}
			return reference >= altitude.altitude.radians
		}

		var instants: [(Moon.LocalEclipse.Contact, Instant<TT>)] = [(.penumbralBegins, eclipse.penumbralPhase.lowerBound)]
		if let partial = eclipse.partialPhase {
			instants.append((.partialBegins, partial.lowerBound))
		}
		if let total = eclipse.totalPhase {
			instants.append((.totalBegins, total.lowerBound))
		}
		instants.append((.greatestEclipse, eclipse.greatestEclipse))
		if let total = eclipse.totalPhase {
			instants.append((.totalEnds, total.upperBound))
		}
		if let partial = eclipse.partialPhase {
			instants.append((.partialEnds, partial.upperBound))
		}
		instants.append((.penumbralEnds, eclipse.penumbralPhase.upperBound))

		var contacts: [Moon.LocalEclipse.Circumstance] = []
		for (contact, instant) in instants {
			do throws(EphemerisError) {
				let observation = try Observation(observer: self, instant: instant, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris)
				let apparent = try observation.apparentPlace(of: moon)
				let unrefracted: ObservedPlace
				let place: ObservedPlace
				do throws(ObserverError) {
					unrefracted = try observation.observedPlace(of: apparent)
					place = conditions == nil ? unrefracted : try observation.observedPlace(of: apparent, conditions: conditions)
				} catch {
					// The observer is a site, and the Moon is never at its origin.
					throw .invalidState
				}
				contacts.append(Moon.LocalEclipse.Circumstance(contact: contact, instant: instant, place: place, isMoonUp: isUp(unrefracted)))
			} catch {
				throw .ephemeris(error)
			}
		}

		let events: [RiseTransitSetEvent]
		do throws(RiseTransitSetError) {
			events = try riseTransitSetEvents(from: eclipse.penumbralPhase.lowerBound, to: eclipse.penumbralPhase.upperBound, context: TT.defaultContext, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
				do throws(EphemerisError) {
					return try observation.apparentPlace(of: moon)
				} catch {
					throw .ephemeris(error)
				}
			}.filter { $0.kind == .rise || $0.kind == .set }
		} catch {
			throw Moon.EclipseError(error)
		}

		// The Moon is up from the first contact, or from a rise, until a set, or the last
		// contact.
		var intervals: [ClosedRange<Instant<TT>>] = []
		var risen: Instant<TT>? = contacts[0].isMoonUp ? eclipse.penumbralPhase.lowerBound : nil
		for event in events {
			switch event.kind {
			case .rise:
				if risen == nil {
					risen = event.instant
				}
			case .set:
				if let start = risen {
					intervals.append(start ... event.instant)
					risen = nil
				}
			default:
				break
			}
		}
		if let start = risen {
			intervals.append(start ... eclipse.penumbralPhase.upperBound)
		}
		return Moon.LocalEclipse(eclipse: eclipse, observer: self, contacts: contacts, moonrisesAndMoonsets: events, visibleIntervals: intervals)
	}

	/// Returns the local circumstances of an eclipse of the Moon at this site, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - eclipse: The eclipse.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/arcsecond``,
	///     which places the Moon within about 1".
	/// - Returns: The local circumstances.
	/// - Throws: A ``Moon/EclipseError``, as the method taking an ephemeris does.
	public func localCircumstances(of eclipse: Moon.Eclipse, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .arcsecond) throws(Moon.EclipseError) -> Moon.LocalEclipse {
		try localCircumstances(of: eclipse, moon: BuiltInEphemeris.Body.moon, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the eclipses of the Moon greatest in an interval that are visible from this
	/// site, with their local circumstances, in order.
	///
	/// An eclipse is visible if the Moon is up at some time from its first contact with the
	/// penumbra to its last.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site, and whose
	///     celestial pole offsets and precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The visible eclipses' local circumstances, in order of greatest eclipse.
	/// - Throws: ``Moon/EclipseError/noHorizon`` if the observer is the center of the Earth,
	///   or a ``Moon/EclipseError`` as for
	///   ``Moon/eclipses(of:from:to:context:earthOrientation:ephemeris:shadowModel:)``.
	public func visibleLunarEclipses<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> [Moon.LocalEclipse] {
		guard case .site = location else {
			throw .noHorizon
		}
		let eclipses = try Moon.eclipses(of: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, shadowModel: shadowModel)
		var visible: [Moon.LocalEclipse] = []
		for eclipse in eclipses {
			let local = try localCircumstances(of: eclipse, moon: moon, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: ephemeris)
			if local.isVisible {
				visible.append(local)
			}
		}
		return visible
	}

	/// Returns the eclipses of the Moon greatest in an interval that are visible from this
	/// site, with their local circumstances, in order, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site, and whose
	///     celestial pole offsets and precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``, as for
	///     `Moon.eclipses(from:to:)`.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The visible eclipses' local circumstances, in order of greatest eclipse.
	/// - Throws: A ``Moon/EclipseError``, as the method taking an ephemeris does.
	public func visibleLunarEclipses<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> [Moon.LocalEclipse] {
		try visibleLunarEclipses(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), shadowModel: shadowModel)
	}
}
