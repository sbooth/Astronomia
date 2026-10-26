//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// The constants of the search for the phases of the Moon.
	enum Phases {
		/// The mean motion of the excess of the Moon's ecliptic longitude over the Sun's, a turn
		/// per synodic month, in radians per day, which predicts the next phase.
		static let meanMotion: Double = twoPi / 29.530_589
		/// The half-width of the bracket around a predicted phase, in days.
		///
		/// The excess grows by between about 10.8° and 14.4° a day, so a prediction across at
		/// most a quarter of a turn is within about 1.2 days.
		static let margin: Double = 3.0
		/// The longest interval holding every phase, a synodic month and the margin, in days.
		static let month: Double = 29.530_589 + margin
	}
}

extension Moon {
	/// Returns the phases of the Moon in an interval, in order.
	///
	/// The Moon's and the Sun's places are their apparent places seen from the center of the
	/// Earth, with light time, aberration, and the gravitational deflection of light, converted to
	/// ``TrueEclipticOfDate``. Each phase is found to 0.1 s.
	///
	/// ```swift
	/// let full = try Moon.nextPhase(.fullMoon, after: instant)
	/// let phases = try Moon.phases(from: start, to: end)
	/// ```
	///
	/// These are the instants of the principal phases. For the phase the Moon is in at any
	/// instant, one of eight, as "Waxing Gibbous", see ``Moon/PhaseName``.
	///
	/// The excess of the Moon's longitude over the Sun's grows about 0.5" a second, so an error of
	/// 1" in either
	/// place moves a phase by about 2 s. The methods taking the built-in ephemeris default to its
	/// full precision, at about 0.3 s for each phase in a release build. The phases from 2000 to
	/// 2049 are within 0.03 s of Skyfield's with DE421; at ``SeriesPrecision/tenthArcsecond`` they
	/// are within 0.11 s, at about 45 ms each, and at ``SeriesPrecision/arcsecond`` within 1 s, at
	/// about 12 ms each.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The phases, in order of their instants.
	/// - Throws:
	///   - ``Moon/PhaseError/invalidInterval`` if `end` is before `start`.
	///   - ``Moon/PhaseError/timescaleConversion(_:)`` if the interval can't be converted to TT.
	///   - ``Moon/PhaseError/ephemeris(_:)`` if a place of the Sun or the Moon in the interval
	///     fails, as for an ``Observation``, such as outside the ephemeris's coverage.
	public static func phases<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Moon.PhaseError) -> [Moon.PhaseEvent] {
		try phases(of: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, only: nil, stoppingAfterFirst: false)
	}

	/// Returns the phases of the Moon of one kind or every kind in an interval, in order.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - kind: The only phase to find, or `nil` for every phase. Other phases are bracketed,
	///     to step past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first phase found, without evaluating the
	///     ephemeris for the rest of the interval.
	/// - Returns: The phases, in order of their instants.
	/// - Throws: A ``Moon/PhaseError``, as the public method does.
	static func phases<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, earthOrientation: EarthOrientation, ephemeris: E, only kind: Moon.PhaseEvent.Kind?, stoppingAfterFirst: Bool) throws(Moon.PhaseError) -> [Moon.PhaseEvent] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			throw Moon.PhaseError(error)
		}
		let search = QuarterSearch(length: interval.length, meanMotion: Phases.meanMotion, margin: Phases.margin) { (days: Double) throws(Moon.PhaseError) -> QuarterSearch<Moon.PhaseError>.Sample in
			let instant: Instant<TT>
			do throws(SearchInterval.Failure) {
				instant = try interval.instant(days)
			} catch {
				throw Moon.PhaseError(error)
			}
			let sun: ApparentPlace<ICRS>
			let moonPlace: ApparentPlace<ICRS>
			do throws(EphemerisError) {
				let sky = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
				sun = try sky.apparentPlace(of: E.sun)
				moonPlace = try sky.apparentPlace(of: moon)
			} catch {
				throw .ephemeris(error)
			}
			// One rotation to the ecliptic of date serves both places.
			let rotation = ICRS.rotation(to: TrueEclipticOfDate.self, at: instant, earthOrientation: earthOrientation)
			let sunLongitude = (rotation * sun.position).spherical.longitude.radians
			let moonLongitude = (rotation * moonPlace.position).spherical.longitude.radians
			var excess = (moonLongitude - sunLongitude).truncatingRemainder(dividingBy: twoPi)
			if excess < 0 {
				excess += twoPi
			}
			return QuarterSearch.Sample(time: min(days, interval.length), instant: instant, angle: excess < twoPi ? excess : 0)
		}
		return try search.events(only: kind?.index, stoppingAfterFirst: stoppingAfterFirst).map { Moon.PhaseEvent(kind: Moon.PhaseEvent.Kind.allCases[$0.quarter], instant: $0.instant) }
	}

	/// Returns the phases of the Moon in an interval, in order, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The phases, in order of their instants.
	/// - Throws: A ``Moon/PhaseError``, as the method taking an ephemeris does.
	public static func phases<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full) throws(Moon.PhaseError) -> [Moon.PhaseEvent] {
		try phases(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first phase of a kind after an instant.
	///
	/// The search covers at most a synodic month from the instant, stepping past other phases
	/// with a couple of places of the Sun and the Moon each, refining only the requested phase,
	/// and evaluating the ephemeris no further than it needs to bracket it, so a phase just
	/// before the end of the ephemeris's coverage is found. A phase within 0.5 s of the instant,
	/// as when the instant is a phase found earlier, is taken as at it, not after it.
	///
	/// - Parameters:
	///   - kind: The phase.
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The phase.
	/// - Throws:
	///   - ``Moon/PhaseError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``Moon/PhaseError/invalidInterval`` if a synodic month after `instant` can't be
	///     represented.
	///   - ``Moon/PhaseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for an
	///     ``Observation``, such as for a phase past the ephemeris's coverage.
	///   - ``Moon/PhaseError/phaseNotFound`` if the phase isn't within a synodic month after
	///     `instant`, as for an ephemeris whose Moon doesn't move as the Moon does.
	public static func nextPhase<E: GeocentricEphemeris, Scale: Timescale>(_ kind: Moon.PhaseEvent.Kind, of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Moon.PhaseError) -> Moon.PhaseEvent {
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		var from = start
		// A phase at the start, as when `instant` is a phase found earlier, may be found a
		// little after it, within the precision of the two searches, so a phase within 0.5 s
		// is taken as at the start, and the search then resumes a day later.
		for _ in 0 ..< 2 {
			let end: Instant<TT>
			do throws(JulianDateError) {
				end = Instant(try from.julianDate.adding(days: Phases.month))
			} catch {
				throw .invalidInterval
			}
			let found = try phases(of: moon, from: from, to: end, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: kind, stoppingAfterFirst: true).first
			guard let found else { break }
			if (found.instant.julianDate.daysSinceJ2000 - start.julianDate.daysSinceJ2000) * secondsPerDay > 0.5 {
				return found
			}
			do throws(JulianDateError) {
				from = Instant(try found.instant.julianDate.adding(days: 1))
			} catch {
				throw .invalidInterval
			}
		}
		// Every phase occurs within a synodic month, unless a custom ephemeris's Moon doesn't
		// move as the Moon does.
		throw .phaseNotFound
	}

	/// Returns the first phase of a kind after an instant, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - kind: The phase.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The phase.
	/// - Throws: A ``Moon/PhaseError``, as the method taking an ephemeris does.
	public static func nextPhase<Scale: Timescale>(_ kind: Moon.PhaseEvent.Kind, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full) throws(Moon.PhaseError) -> Moon.PhaseEvent {
		try nextPhase(kind, of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}

extension Moon {
	/// Returns how the Moon is lit by the Sun at an instant, with the built-in ephemeris.
	///
	/// This is the ``Observation/illumination(of:)`` of the Moon in an observation at the
	/// instant.
	///
	/// - Parameters:
	///   - instant: The instant.
	///   - context: Observational data for converting `instant`.
	///   - observer: The observer, by default the center of the Earth.
	///   - earthOrientation: Observed Earth orientation, whose UT1 places a site, and whose
	///     celestial pole offsets and precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The Moon's phase angle, illuminated fraction, elongation and its side of the
	///   Sun, and bright limb.
	/// - Throws: ``IlluminationError/ephemeris(_:)`` if the observation or a place fails, as
	///   for ``Observation``, such as outside the ephemeris's coverage.
	public static func illumination<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, observer: Observer = .geocenter, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full) throws(IlluminationError) -> Illumination {
		let observation: Observation<BuiltInEphemeris>
		do throws(EphemerisError) {
			observation = try observer.observation(at: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
		} catch {
			throw .ephemeris(error)
		}
		return try observation.illumination(of: .moon)
	}
}
