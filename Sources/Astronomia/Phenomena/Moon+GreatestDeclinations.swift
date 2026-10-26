//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// The constants of the search for the Moon's greatest declinations.
	enum GreatestDeclinations {
		/// The time between the samples that bracket a greatest declination, in days, less than the
		/// least time between them, about 12.5 days.
		static let step: Double = 1
		/// The time after a greatest declination before the next can be bracketed, in days: the
		/// least time between them, less the step and a margin.
		static let skip: Double = 10
		/// The longest interval holding a greatest declination of each kind, a tropical month and a
		/// margin, in days.
		///
		/// Greatest declinations of a kind are between about 27.2 and 27.6 days apart.
		static let month: Double = 30
	}
}

extension Moon {
	/// Returns the greatest declinations of the Moon in an interval, in order.
	///
	/// Each tropical month, about 27.3 days, the Moon's declination swings from a greatest north to
	/// a greatest south and back, about 13.7 days apart. These extremes are also called the Moon's
	/// maximum declinations, as by Meeus, and lunistices or monthly lunar standstills. The
	/// greatest of them over the 18.6-year cycle of the Moon's nodes are the major and minor lunar
	/// standstills, which these are not.
	///
	/// The Moon's place is its apparent place seen from the center of the Earth, with light time,
	/// aberration, and the gravitational deflection of light, converted to
	/// ``TrueEquatorOfDate``. Each greatest declination is found to 0.1 s.
	///
	/// ```swift
	/// let north = try Moon.nextGreatestDeclination(.north, after: instant)
	/// let extremes = try Moon.greatestDeclinations(from: start, to: end)
	/// ```
	///
	/// Near its extreme the declination changes by only about 1 mas in a minute, so its instant is
	/// far more sensitive to errors in the Moon's place than the declination reached. Each places
	/// the Moon about 20 times; the methods taking the built-in ephemeris default to its full
	/// precision, at about 0.45 s each in a release build. The greatest declinations from 2000 to
	/// 2049 are within 0.21 s and 7 mas of Skyfield's with DE421; at
	/// ``SeriesPrecision/tenthArcsecond`` they are within 0.41 s and 47 mas, at about 75 ms each,
	/// and at ``SeriesPrecision/arcsecond`` within 5 s and 0.37", at about 20 ms each.
	///
	/// The ephemeris is evaluated up to 10 s outside the interval, so a greatest declination
	/// at either end is found.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The greatest declinations, in order of their instants.
	/// - Throws:
	///   - ``Moon/GreatestDeclinationError/invalidInterval`` if `end` is before `start`.
	///   - ``Moon/GreatestDeclinationError/timescaleConversion(_:)`` if the interval can't be
	///     converted to TT.
	///   - ``Moon/GreatestDeclinationError/ephemeris(_:)`` if a place of the Moon in the
	///     interval fails, as for an ``Observation``, such as outside the ephemeris's coverage.
	public static func greatestDeclinations<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Moon.GreatestDeclinationError) -> [Moon.GreatestDeclinationEvent] {
		try greatestDeclinations(of: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, only: nil, stoppingAfterFirst: false)
	}

	/// Returns the greatest declinations of the Moon of one kind or both in an interval, in
	/// order.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - kind: The only kind to find, or `nil` for both. The others are bracketed, to step
	///     past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first greatest declination found,
	///     without evaluating the ephemeris for the rest of the interval.
	/// - Returns: The greatest declinations, in order of their instants.
	/// - Throws: A ``Moon/GreatestDeclinationError``, as the public method does.
	static func greatestDeclinations<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, earthOrientation: EarthOrientation, ephemeris: E, only kind: Moon.GreatestDeclinationEvent.Kind?, stoppingAfterFirst: Bool) throws(Moon.GreatestDeclinationError) -> [Moon.GreatestDeclinationEvent] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			throw Moon.GreatestDeclinationError(error)
		}
		let search = ExtremumSearch(length: interval.length, step: GreatestDeclinations.step, skip: GreatestDeclinations.skip) { (days: Double) throws(Moon.GreatestDeclinationError) -> Double in
			// The search runs a little past the ends of the interval, so the instant isn't
			// clamped to it.
			let instant: Instant<TT>
			do throws(JulianDateError) {
				instant = Instant(try interval.start.julianDate.adding(days: days))
			} catch {
				throw .invalidInterval
			}
			do throws(EphemerisError) {
				let sky = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
				return try sky.apparentPlace(of: moon, in: TrueEquatorOfDate.self).position.spherical.declination.radians
			} catch {
				throw .ephemeris(error)
			}
		}
		let maxima = kind.map { $0 == .north }
		var events: [Moon.GreatestDeclinationEvent] = []
		for extreme in try search.extremes(only: maxima, stoppingAfterFirst: stoppingAfterFirst) {
			do throws(SearchInterval.Failure) {
				events.append(Moon.GreatestDeclinationEvent(kind: extreme.isMaximum ? .north : .south, instant: try interval.instant(extreme.time), declination: Angle(radians: extreme.value)))
			} catch {
				throw Moon.GreatestDeclinationError(error)
			}
		}
		return events
	}

	/// Returns the greatest declinations of the Moon in an interval, in order, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The greatest declinations, in order of their instants.
	/// - Throws: A ``Moon/GreatestDeclinationError``, as the method taking an ephemeris does.
	public static func greatestDeclinations<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full) throws(Moon.GreatestDeclinationError) -> [Moon.GreatestDeclinationEvent] {
		try greatestDeclinations(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first greatest declination of a kind after an instant.
	///
	/// The search covers at most a tropical month and a margin from the instant, stepping past
	/// a greatest declination of the other kind without refining it, and stops at the one
	/// found. A greatest declination within 0.5 s of the instant, as when the instant is one
	/// found earlier, is taken as at it, not after it.
	///
	/// - Parameters:
	///   - kind: The side of the equator.
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The greatest declination.
	/// - Throws:
	///   - ``Moon/GreatestDeclinationError/timescaleConversion(_:)`` if `instant` can't be
	///     converted to TT.
	///   - ``Moon/GreatestDeclinationError/invalidInterval`` if a tropical month after
	///     `instant` can't be represented.
	///   - ``Moon/GreatestDeclinationError/ephemeris(_:)`` if a place of the Moon fails, as for
	///     an ``Observation``, such as past the ephemeris's coverage.
	///   - ``Moon/GreatestDeclinationError/greatestDeclinationNotFound`` if there is none
	///     within a tropical month and a margin after `instant`, as for an ephemeris whose
	///     Moon doesn't move as the Moon does.
	public static func nextGreatestDeclination<E: GeocentricEphemeris, Scale: Timescale>(_ kind: Moon.GreatestDeclinationEvent.Kind, of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(Moon.GreatestDeclinationError) -> Moon.GreatestDeclinationEvent {
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		var from = start
		// One at the start, as when `instant` is one found earlier, may be found a little after
		// it, within the precision of the two searches, so one within 0.5 s is taken as at the
		// start, and the search then resumes a day later.
		for _ in 0 ..< 2 {
			let end: Instant<TT>
			do throws(JulianDateError) {
				end = Instant(try from.julianDate.adding(days: GreatestDeclinations.month))
			} catch {
				throw .invalidInterval
			}
			let found = try greatestDeclinations(of: moon, from: from, to: end, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: kind, stoppingAfterFirst: true).first
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
		throw .greatestDeclinationNotFound
	}

	/// Returns the first greatest declination of a kind after an instant, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - kind: The side of the equator.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The greatest declination.
	/// - Throws: A ``Moon/GreatestDeclinationError``, as the method taking an ephemeris does.
	public static func nextGreatestDeclination<Scale: Timescale>(_ kind: Moon.GreatestDeclinationEvent.Kind, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full) throws(Moon.GreatestDeclinationError) -> Moon.GreatestDeclinationEvent {
		try nextGreatestDeclination(kind, of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}
