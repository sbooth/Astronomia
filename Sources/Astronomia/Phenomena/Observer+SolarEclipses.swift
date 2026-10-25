//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Sun and the Moon seen from a site at a time, during an eclipse of the Sun.
struct LocalSolarEclipseSample {
	/// The time, in days after the start of the eclipse's partial phase on the Earth.
	let time: Double
	/// The angle between the centers of the Sun and the Moon, in radians.
	let separation: Double
	/// The Sun's semidiameter, in radians.
	let sun: Double
	/// The Moon's semidiameter for the partial phase, in radians.
	let penumbralMoon: Double
	/// The Moon's semidiameter for the annular or total phase, in radians.
	let umbralMoon: Double

	/// The separation less the sum of the radii, negative while the Moon covers part of the Sun.
	var partialDistance: Double {
		separation - (sun + penumbralMoon)
	}

	/// The separation less the difference of the radii, negative while one disk is within the
	/// other.
	var centralDistance: Double {
		separation - abs(sun - umbralMoon)
	}

	/// The fraction of the Sun's diameter the Moon covers, which exceeds 1 within the umbra, as
	/// the magnitude of an ``Sun/Eclipse`` from the radii of the shadow's cones.
	var magnitude: Double {
		(sun + penumbralMoon - separation) / (2 * sun + penumbralMoon - umbralMoon)
	}

	/// The fraction of the Sun's area the Moon's disk covers, of its radius for the total or
	/// annular phase, as NASA's catalogs give it.
	var obscuration: Double {
		let (r, s, d) = (sun, umbralMoon, separation)
		if d >= r + s {
			return 0
		}
		if d <= abs(r - s) {
			return s >= r ? 1 : (s * s) / (r * r)
		}
		// The area of the lens where the disks overlap, as a fraction of the Sun's
		let a = r * r * Math.acos((d * d + r * r - s * s) / (2 * d * r))
		let b = s * s * Math.acos((d * d + s * s - r * r) / (2 * d * s))
		let c = 0.5 * ((-d + r + s) * (d + r - s) * (d - r + s) * (d + r + s)).squareRoot()
		return min(1, max(0, (a + b - c) / (.pi * r * r)))
	}
}

extension Observer {
	/// Returns the local circumstances of an eclipse of the Sun at this site: how it is seen,
	/// its contacts there, the Sun's place at each, its rises and sets during the eclipse, and
	/// when it is up; or `nil` if the Moon doesn't cover the Sun from this site.
	///
	/// The Sun's and the Moon's places are their apparent places seen from the site, without
	/// refraction, and their radii those of the eclipse's ``Sun/Eclipse/Radii``. The magnitude
	/// is greatest at maximum, found from samples 10 minutes apart over the eclipse's partial
	/// phase on the Earth, then by parabolas through closer samples, to about 0.01 s; each
	/// contact, where the separation of the centers equals the sum or the difference of the
	/// radii, is found to 0.01 s.
	///
	/// With NASA's ΔT, the circumstances of the total eclipse of 2001 June 21 match NASA's
	/// bulletin and path for it, computed with the VSOP87 and ELP2000-85 theories: on the
	/// central line, the central duration within 0.1 s, and the position angles of the contacts
	/// within 1°; and at sites of the partial eclipse, the contacts within 0.2 s, their position
	/// angles within 1°, and the magnitude and obscuration within the rounding of their three
	/// places. At the place of greatest eclipse the central phase is that the search for
	/// eclipses finds from the shadow's geometry, within 0.05 s.
	///
	/// NASA's tables give the magnitude of an eclipse in progress at sunrise or sunset at the
	/// horizon; ``Sun/LocalEclipse/magnitude`` is at maximum, which may be below it.
	///
	/// - Parameters:
	///   - eclipse: The eclipse.
	///   - moon: The Moon.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction. Whether the Sun is up is decided by `altitude` alone.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The local circumstances, or `nil` if the eclipse isn't seen from the site.
	/// - Throws:
	///   - ``Sun/EclipseError/noHorizon`` if the observer is the center of the Earth.
	///   - ``Sun/EclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, or UT1 can't be found.
	public func localCircumstances<E: GeocentricEphemeris>(of eclipse: Sun.Eclipse, moon: E.Body, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Sun.EclipseError) -> Sun.LocalEclipse? {
		guard case let .site(_, latitude: latitude, longitude: _) = location else {
			throw .noHorizon
		}
		let origin = eclipse.partialPhase.lowerBound
		let length = Astrometry.days(from: Instant<TDB>(origin.julianDate), to: Instant<TDB>(eclipse.partialPhase.upperBound.julianDate))
		let earthRadius = earthEquatorialRadius.astronomicalUnits
		let sunRadius = Math.sin(eclipse.radii.sun.radians)
		/// Returns the instant some days after the start of the partial phase.
		func instant(_ days: Double) throws(Sun.EclipseError) -> Instant<TT> {
			do throws(JulianDateError) {
				return Instant(try origin.julianDate.adding(days: days))
			} catch {
				throw .invalidInterval
			}
		}
		/// Returns the observation and the apparent places of the Sun and the Moon at a time.
		func places(_ days: Double) throws(Sun.EclipseError) -> (observation: Observation<E>, sun: ApparentPlace<ICRS>, moon: ApparentPlace<ICRS>) {
			let instant = try instant(days)
			do throws(EphemerisError) {
				let observation = try Observation(observer: self, instant: instant, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris)
				return (observation, try observation.apparentPlace(of: E.sun), try observation.apparentPlace(of: moon))
			} catch {
				throw .ephemeris(error)
			}
		}
		/// Returns the Sun and the Moon seen from the site at a time.
		func sample(_ days: Double) throws(Sun.EclipseError) -> LocalSolarEclipseSample {
			let (_, sun, moon) = try places(days)
			let (s, m) = (sun.position.vector, moon.position.vector)
			let (sunDistance, moonDistance) = (s.length, m.length)
			guard sunDistance > 0, moonDistance > 0 else {
				throw .ephemeris(.invalidState)
			}
			let separation = Math.atan2(s.cross(m).length, s.dot(m))
			return LocalSolarEclipseSample(time: days, separation: separation, sun: Math.asin(min(1, sunRadius / sunDistance)), penumbralMoon: Math.asin(min(1, eclipse.radii.penumbralMoon * earthRadius / moonDistance)), umbralMoon: Math.asin(min(1, eclipse.radii.umbralMoon * earthRadius / moonDistance)))
		}

		// Maximum: the least separation among samples 10 minutes apart, then the vertex of
		// parabolas through the squared separation, at each step until it is within the step.
		// Where the eclipse is partial the magnitude is greatest seconds from there, as the
		// Moon's apparent radius changes as it rises or sets, and the vertex of parabolas
		// through the magnitude finds it; within the central phase the magnitude peaks sharply
		// at the least separation.
		let grid = 10.0 / 1440
		let count = max(2, Int((length / grid).rounded(.up)))
		var samples: [LocalSolarEclipseSample] = []
		for index in 0 ... count {
			samples.append(try sample(length * Double(index) / Double(count)))
		}
		/// Returns the time of the vertex of parabolas through a function of the samples near a
		/// time, toward its least or its greatest.
		func vertex(near time: Double, steps: [Double], function: (LocalSolarEclipseSample) -> Double, greatest: Bool) throws(Sun.EclipseError) -> Double {
			var center = time
			let sign = greatest ? -1.0 : 1.0
			for step in steps {
				for _ in 0 ..< 20 {
					let (before, at, after) = (sign * function(try sample(center - step)), sign * function(try sample(center)), sign * function(try sample(center + step)))
					let curvature = before - 2 * at + after
					guard curvature > 0 else {
						center += before < after ? -step : step
						continue
					}
					let offset = step * (before - after) / (2 * curvature)
					center += max(-2 * step, min(2 * step, offset))
					if abs(offset) <= step {
						break
					}
				}
			}
			return min(max(center, 0), length)
		}
		let nearest = samples.min { $0.separation < $1.separation }!
		var center = try vertex(near: nearest.time, steps: [grid / 2, 1.0 / 1440, 0.1 / 1440, 0.01 / 1440, 0.001 / 1440], function: { $0.separation * $0.separation }, greatest: false)
		if try sample(center).centralDistance >= 0 {
			center = try vertex(near: center, steps: [0.1 / 1440, 0.01 / 1440, 0.001 / 1440], function: \.magnitude, greatest: true)
		}
		var best: LocalSolarEclipseSample
		best = try sample(center)
		guard best.partialDistance < 0 else {
			return nil
		}

		/// Returns the sample where a function of the samples, negative at maximum, crosses zero
		/// before or after it, bracketed by the grid's samples.
		func contact(before: Bool, function: (LocalSolarEclipseSample) -> Double) throws(Sun.EclipseError) -> LocalSolarEclipseSample {
			let outside = before ? samples.last { $0.time < best.time && function($0) >= 0 } : samples.first { $0.time > best.time && function($0) >= 0 }
			// At the ends of the partial phase on the Earth, the penumbra only touches it, so a
			// site within the penumbra is outside it a moment later.
			let far: LocalSolarEclipseSample
			if let outside {
				far = outside
			} else {
				far = try sample(before ? 0 : length)
			}
			let near = before ? (samples.last { $0.time > far.time && $0.time < best.time && function($0) < 0 } ?? best) : (samples.first { $0.time < far.time && $0.time > best.time && function($0) < 0 } ?? best)
			let (lower, upper) = before ? (far, near) : (near, far)
			return try RootFinder.refine(lower, upper, time: \.time, tolerance: 0.01 / secondsPerDay, maximumIterations: 100, evaluate: sample, function: function)
		}
		let first = try contact(before: true) { $0.partialDistance }
		let last = try contact(before: false) { $0.partialDistance }
		let kind: Sun.LocalEclipse.Kind
		var central: (first: LocalSolarEclipseSample, last: LocalSolarEclipseSample)? = nil
		if best.centralDistance < 0 {
			kind = best.umbralMoon > best.sun ? .total : .annular
			central = (try contact(before: true) { $0.centralDistance }, try contact(before: false) { $0.centralDistance })
		} else {
			kind = .partial
		}

		let radius: Distance? = switch altitude.reference {
		case let .upperLimb(radius): radius ?? E.radius(of: E.sun)
		case .center: nil
		}
		let (sinLatitude, cosLatitude) = Math.sincos(latitude)
		var instants: [(Sun.LocalEclipse.Contact, Double)] = [(.partialBegins, first.time)]
		if let central {
			instants.append((.centralBegins, central.first.time))
		}
		instants.append((.maximum, best.time))
		if let central {
			instants.append((.centralEnds, central.last.time))
		}
		instants.append((.partialEnds, last.time))
		var contacts: [Sun.LocalEclipse.Circumstance] = []
		for (contact, time) in instants {
			let (observation, sun, moon) = try places(time)
			let unrefracted: ObservedPlace
			let place: ObservedPlace
			let moonPlace: ObservedPlace
			do throws(ObserverError) {
				unrefracted = try observation.observedPlace(of: sun)
				place = conditions == nil ? unrefracted : try observation.observedPlace(of: sun, conditions: conditions)
				moonPlace = try observation.observedPlace(of: moon)
			} catch {
				// The observer is a site, and the Sun and the Moon are never at its origin.
				throw .ephemeris(.invalidState)
			}
			// The position angle of the Moon's center from the Sun's, from their hour angles and
			// declinations of date, and of the point of contact
			let difference = unrefracted.hourAngle.radians - moonPlace.hourAngle.radians
			let (sinDifference, cosDifference) = Math.sincos(difference)
			let (sinSun, cosSun) = Math.sincos(unrefracted.declination.radians)
			let (sinMoon, cosMoon) = Math.sincos(moonPlace.declination.radians)
			var angle = Math.atan2(sinDifference * cosMoon, cosSun * sinMoon - sinSun * cosMoon * cosDifference)
			if kind == .total, contact == .centralBegins || contact == .centralEnds {
				angle += .pi
			}
			let parallactic = Horizon.parallacticAngle(hourAngle: unrefracted.hourAngle.radians, declination: unrefracted.declination.radians, sinLatitude: sinLatitude, cosLatitude: cosLatitude)
			var reference = unrefracted.altitude.radians
			if let radius {
				reference += Math.asin(min(radius.astronomicalUnits / unrefracted.distance.astronomicalUnits, 1))
			}
			contacts.append(Sun.LocalEclipse.Circumstance(contact: contact, instant: observation.instant, place: place, positionAngle: Angle(radians: Self.normalized(angle)), zenithPositionAngle: Angle(radians: Self.normalized(angle - parallactic)), isSunUp: reference >= altitude.altitude.radians))
		}
		let partialPhase = contacts.first!.instant ... contacts.last!.instant

		let events: [RiseTransitSetEvent]
		do throws(RiseTransitSetError) {
			events = try riseTransitSetEvents(from: partialPhase.lowerBound, to: partialPhase.upperBound, context: TT.defaultContext, altitude: altitude, radius: radius, earthOrientation: earthOrientation, ephemeris: ephemeris) { observation throws(RiseTransitSetError) in
				do throws(EphemerisError) {
					return try observation.apparentPlace(of: E.sun)
				} catch {
					throw .ephemeris(error)
				}
			}.filter { $0.kind == .rise || $0.kind == .set }
		} catch {
			throw Sun.EclipseError(error)
		}
		// The Sun is up from the first contact, or from a rise, until a set, or the last contact.
		var intervals: [ClosedRange<Instant<TT>>] = []
		var risen: Instant<TT>? = contacts[0].isSunUp ? partialPhase.lowerBound : nil
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
			intervals.append(start ... partialPhase.upperBound)
		}
		let centralPhase = central == nil ? nil : contacts.first { $0.contact == .centralBegins }!.instant ... contacts.first { $0.contact == .centralEnds }!.instant
		return Sun.LocalEclipse(eclipse: eclipse, observer: self, kind: kind, magnitude: best.magnitude, obscuration: best.obscuration, partialPhase: partialPhase, centralPhase: centralPhase, contacts: contacts, sunrisesAndSunsets: events, visibleIntervals: intervals)
	}

	/// Returns an angle in radians reduced to the right-open interval [0, 2π).
	static func normalized(_ angle: Double) -> Double {
		let reduced = angle.truncatingRemainder(dividingBy: twoPi)
		return reduced < 0 ? reduced + twoPi : reduced
	}

	/// Returns the local circumstances of an eclipse of the Sun at this site, with the built-in
	/// ephemeris, or `nil` if the Moon doesn't cover the Sun from this site.
	///
	/// - Parameters:
	///   - eclipse: The eclipse.
	///   - conditions: The atmosphere at the site, which refracts the places at the contacts,
	///     or `nil` for no refraction.
	///   - altitude: The altitude of rise and set, by default the standard -34' of the
	///     upper limb.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places the site.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``: the
	///     Moon's place is relative to the Sun's 0.5" a second, so an error of 1" in it moves a
	///     contact by about 2 s.
	/// - Returns: The local circumstances, or `nil` if the eclipse isn't seen from the site.
	/// - Throws: A ``Sun/EclipseError``, as the method taking an ephemeris does.
	public func localCircumstances(of eclipse: Sun.Eclipse, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(Sun.EclipseError) -> Sun.LocalEclipse? {
		try localCircumstances(of: eclipse, moon: BuiltInEphemeris.Body.moon, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the eclipses of the Sun greatest in an interval that are visible from this site,
	/// with their local circumstances, in order.
	///
	/// An eclipse is visible if the Moon covers part of the Sun from the site at some time when
	/// the Sun is up.
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
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The visible eclipses' local circumstances, in order of greatest eclipse.
	/// - Throws: ``Sun/EclipseError/noHorizon`` if the observer is the center of the Earth,
	///   or a ``Sun/EclipseError`` as for
	///   ``Sun/eclipses(by:from:to:context:earthOrientation:ephemeris:radii:)``.
	public func visibleSolarEclipses<E: GeocentricEphemeris, Scale: Timescale>(by moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, ephemeris: E, radii: Sun.Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> [Sun.LocalEclipse] {
		guard case .site = location else {
			throw .noHorizon
		}
		let eclipses = try Sun.eclipses(by: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, radii: radii)
		var visible: [Sun.LocalEclipse] = []
		for eclipse in eclipses {
			if let local = try localCircumstances(of: eclipse, moon: moon, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: ephemeris), local.isVisible {
				visible.append(local)
			}
		}
		return visible
	}

	/// Returns the eclipses of the Sun greatest in an interval that are visible from this site,
	/// with their local circumstances, in order, with the built-in ephemeris.
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
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The visible eclipses' local circumstances, in order of greatest eclipse.
	/// - Throws: A ``Sun/EclipseError``, as the method taking an ephemeris does.
	public func visibleSolarEclipses<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, conditions: AtmosphericConditions? = nil, altitude: EventAltitude = .standard, earthOrientation: EarthOrientation = .model, precision: Precision = .full, radii: Sun.Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> [Sun.LocalEclipse] {
		try visibleSolarEclipses(by: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, conditions: conditions, altitude: altitude, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), radii: radii)
	}
}
