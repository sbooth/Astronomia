//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The principal phases of the Moon: the instants when the Moon's apparent geocentric ecliptic
/// longitude, in the true ecliptic and equinox of date, exceeds the Sun's by 0°, 90°, 180°, or
/// 270°.
///
/// The Moon's and the Sun's places are their apparent places seen from the center of the
/// Earth, with light time, aberration, and the gravitational deflection of light, converted to
/// ``TrueEclipticOfDate``. Each phase is found to 0.1 s.
///
/// ```swift
/// let full = try MoonPhases.next(.fullMoon, after: instant)
/// let phases = try MoonPhases.events(from: start, to: end)
/// ```
///
/// The Moon's elongation from the Sun grows about 0.5" a second, so an error of 1" in either
/// place moves a phase by about 2 s. The methods taking the built-in ephemeris default to its
/// full precision, at about 0.3 s for each phase in a release build. The phases from 2000 to
/// 2049 are within 0.03 s of Skyfield's with DE421; at ``Precision/tenthArcsecond`` they are
/// within 0.11 s, at about 45 ms each, and at ``Precision/arcsecond`` within 1 s, at about
/// 12 ms each.
public enum MoonPhases {
	/// The mean motion of the Moon's elongation from the Sun, a turn per synodic month, in
	/// radians per day, which predicts the next phase.
	static let meanMotion: Double = twoPi / 29.530_589
	/// The half-width of the bracket around a predicted phase, in days.
	///
	/// The elongation grows by between about 10.8° and 14.4° a day, so a prediction across at
	/// most a quarter of a turn is within about 1.2 days.
	static let margin: Double = 3.0
	/// The longest interval holding every phase, a synodic month and the margin, in days.
	static let month: Double = 29.530_589 + margin
}

extension MoonPhases {
	/// Returns the phases of the Moon in an interval, in order.
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
	///   - ``MoonPhaseError/invalidInterval`` if `end` is before `start`.
	///   - ``MoonPhaseError/timescaleConversion(_:)`` if the interval can't be converted to TT.
	///   - ``MoonPhaseError/ephemeris(_:)`` if a place of the Sun or the Moon in the interval
	///     fails, as for an ``Observation``, such as outside the ephemeris's coverage.
	public static func events<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(MoonPhaseError) -> [MoonPhaseEvent] {
		try events(of: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, stoppingAt: nil)
	}

	/// Returns the phases of the Moon in an interval, in order, up to the first of a kind.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - last: The only phase to find, after which to stop, without evaluating the ephemeris
	///     for the rest of the interval, or `nil` for every phase. Other phases are bracketed,
	///     to step past them, but not refined or returned.
	/// - Returns: The phases, in order of their instants.
	/// - Throws: A ``MoonPhaseError``, as the public method does.
	static func events<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, earthOrientation: EarthOrientation, ephemeris: E, stoppingAt last: MoonPhaseEvent.Kind?) throws(MoonPhaseError) -> [MoonPhaseEvent] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			throw MoonPhaseError(error)
		}
		let search = QuarterSearch(length: interval.length, meanMotion: meanMotion, margin: margin) { (days: Double) throws(MoonPhaseError) -> QuarterSearch<MoonPhaseError>.Sample in
			let instant: Instant<TT>
			do throws(SearchInterval.Failure) {
				instant = try interval.instant(days)
			} catch {
				throw MoonPhaseError(error)
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
			var elongation = (moonLongitude - sunLongitude).truncatingRemainder(dividingBy: twoPi)
			if elongation < 0 {
				elongation += twoPi
			}
			return QuarterSearch.Sample(time: min(days, interval.length), instant: instant, angle: elongation < twoPi ? elongation : 0)
		}
		return try search.events(stoppingAt: last?.index).map { MoonPhaseEvent(kind: MoonPhaseEvent.Kind.allCases[$0.quarter], instant: $0.instant) }
	}

	/// Returns the phases of the Moon in an interval, in order, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The phases, in order of their instants.
	/// - Throws: A ``MoonPhaseError``, as the method taking an ephemeris does.
	public static func events<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(MoonPhaseError) -> [MoonPhaseEvent] {
		try events(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first instant of a phase after an instant.
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
	/// - Returns: The instant of the phase.
	/// - Throws:
	///   - ``MoonPhaseError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``MoonPhaseError/invalidInterval`` if a synodic month after `instant` can't be
	///     represented.
	///   - ``MoonPhaseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for an
	///     ``Observation``, such as for a phase past the ephemeris's coverage.
	public static func next<E: GeocentricEphemeris, Scale: Timescale>(_ kind: MoonPhaseEvent.Kind, of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(MoonPhaseError) -> Instant<TT> {
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
				end = Instant(try from.julianDate.adding(days: month))
			} catch {
				throw .invalidInterval
			}
			let found = try events(of: moon, from: from, to: end, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, stoppingAt: kind).first
			guard let found else { break }
			if (found.instant.julianDate.daysSinceJ2000 - start.julianDate.daysSinceJ2000) * secondsPerDay > 0.5 {
				return found.instant
			}
			do throws(JulianDateError) {
				from = Instant(try found.instant.julianDate.adding(days: 1))
			} catch {
				throw .invalidInterval
			}
		}
		// Every phase occurs within a synodic month, unless a custom ephemeris's Moon doesn't
		// move as the Moon does.
		throw .invalidInterval
	}

	/// Returns the first instant of a phase after an instant, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - kind: The phase.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The instant of the phase.
	/// - Throws: A ``MoonPhaseError``, as the method taking an ephemeris does.
	public static func next<Scale: Timescale>(_ kind: MoonPhaseEvent.Kind, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(MoonPhaseError) -> Instant<TT> {
		try next(kind, of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}
