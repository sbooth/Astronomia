//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// The constants of the search for the Moon's perigees and apogees.
	enum Apsides {
		/// The time between the samples that bracket an apsis, in days, less than the least time
		/// between them, about 11.7 days.
		static let step: Double = 1
		/// The time after an apsis before the next can be bracketed, in days: the least time
		/// between them, less the step and a margin.
		static let skip: Double = 9
		/// The longest interval holding an apsis of each kind, the longest time between apsides of
		/// a kind and a margin, in days.
		///
		/// Apsides of a kind are between about 24.7 and 28.6 days apart.
		static let month: Double = 31
	}
}

extension Moon {
	/// Returns the perigees and apogees of the Moon in an interval, in order.
	///
	/// The Moon passes perigee and apogee once each anomalistic month, about 27.6 days, but the Sun
	/// perturbs its orbit enough that perigees are between about 24.7 and 28.6 days apart, and a
	/// perigee and the next apogee between about 11.7 and 16.1 days. Perigees are about 356,400 km
	/// to 370,400 km from the Earth, and apogees about 404,000 km to 406,700 km.
	///
	/// The distance is geometric: from the center of the Earth to the center of the Moon at the
	/// same instant, without light time, as almanacs and Meeus give it. The Moon is seen at its
	/// nearest or farthest about 1.3 s later, the light time. Each perigee and apogee is found to
	/// 0.1 s.
	///
	/// ```swift
	/// let perigee = try Moon.nextApsis(.perigee, after: instant)
	/// let apsides = try Moon.apsides(from: start, to: end)
	/// ```
	///
	/// Near an apsis the distance changes by only about 0.3 m in a minute, so its instant is far
	/// more sensitive to errors in the Moon's distance than the distance reached: the truncation of
	/// the built-in ephemeris's lower precisions, of hundreds of meters, moves an apsis by many
	/// seconds. Each apsis takes the Moon's state about 26 times, without apparent places; the
	/// methods taking the built-in ephemeris default to its full precision, at about 22 ms each in
	/// a release build. The apsides from 2000 to 2049 are within 0.36 s and 8 m of Skyfield's with
	/// DE421; at ``SeriesPrecision/tenthArcsecond`` they are within 12 s and 0.2 km, at about 3 ms
	/// each, and at ``SeriesPrecision/arcsecond`` within 100 s and 2.3 km.
	///
	/// The Moon's semidiameter, which an apsis makes largest or smallest, is
	/// ``Observation/semidiameter(of:)``.
	///
	/// The ephemeris is evaluated up to 10 s outside the interval, so an apsis at either end is
	/// found.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - ephemeris: The ephemeris of the Earth and the Moon.
	/// - Returns: The perigees and apogees, in order of their instants.
	/// - Throws:
	///   - ``Moon/ApsisError/invalidInterval`` if `end` is before `start`.
	///   - ``Moon/ApsisError/timescaleConversion(_:)`` if the interval can't be converted to TT.
	///   - ``Moon/ApsisError/ephemeris(_:)`` if the Moon's state in the interval fails, such as
	///     outside the ephemeris's coverage, or with ``EphemerisError/invalidState`` if its
	///     distance is NaN or infinite.
	public static func apsides<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(Moon.ApsisError) -> [Moon.ApsisEvent] {
		try apsides(of: moon, from: start, to: end, context: context, ephemeris: ephemeris, only: nil, stoppingAfterFirst: false)
	}

	/// Returns the perigees and apogees of the Moon of one kind or both in an interval, in
	/// order.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - ephemeris: The ephemeris of the Earth and the Moon.
	///   - kind: The only kind to find, or `nil` for both. The others are bracketed, to step
	///     past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first apsis found, without evaluating the
	///     ephemeris for the rest of the interval.
	/// - Returns: The apsides, in order of their instants.
	/// - Throws: A ``Moon/ApsisError``, as the public method does.
	static func apsides<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, ephemeris: E, only kind: Moon.ApsisEvent.Kind?, stoppingAfterFirst: Bool) throws(Moon.ApsisError) -> [Moon.ApsisEvent] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			throw Moon.ApsisError(error)
		}
		let search = ExtremumSearch(length: interval.length, step: Apsides.step, skip: Apsides.skip) { (days: Double) throws(Moon.ApsisError) -> Double in
			// The search runs a little past the ends of the interval, so the instant isn't
			// clamped to it.
			let instant: Instant<TT>
			do throws(JulianDateError) {
				instant = Instant(try interval.start.julianDate.adding(days: days))
			} catch {
				throw .invalidInterval
			}
			do throws(EphemerisError) {
				let distance = try ephemeris.state(of: moon, relativeTo: E.earth, at: instant).position.distance.kilometers
				// A non-finite distance would bracket no apsis, hiding the invalid state.
				guard distance.isFinite else { throw .invalidState }
				return distance
			} catch {
				throw .ephemeris(error)
			}
		}
		let maxima = kind.map { $0 == .apogee }
		var events: [Moon.ApsisEvent] = []
		for extreme in try search.extremes(only: maxima, stoppingAfterFirst: stoppingAfterFirst) {
			do throws(SearchInterval.Failure) {
				events.append(Moon.ApsisEvent(kind: extreme.isMaximum ? .apogee : .perigee, instant: try interval.instant(extreme.time), distance: .kilometers(extreme.value)))
			} catch {
				throw Moon.ApsisError(error)
			}
		}
		return events
	}

	/// Returns the perigees and apogees of the Moon in an interval, in order, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The perigees and apogees, in order of their instants.
	/// - Throws: A ``Moon/ApsisError``, as the method taking an ephemeris does.
	public static func apsides<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, precision: SeriesPrecision = .full) throws(Moon.ApsisError) -> [Moon.ApsisEvent] {
		try apsides(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first perigee or apogee after an instant.
	///
	/// The search covers at most the longest time between apsides of a kind and a margin from
	/// the instant, stepping past an apsis of the other kind without refining it, and stops at
	/// the one found. An apsis within 0.5 s of the instant, as when the instant is one found
	/// earlier, is taken as at it, not after it.
	///
	/// - Parameters:
	///   - kind: The apsis.
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - ephemeris: The ephemeris of the Earth and the Moon.
	/// - Returns: The apsis.
	/// - Throws:
	///   - ``Moon/ApsisError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``Moon/ApsisError/invalidInterval`` if the end of the search can't be represented.
	///   - ``Moon/ApsisError/ephemeris(_:)`` if the Moon's state fails, such as past the
	///     ephemeris's coverage, or with ``EphemerisError/invalidState`` if its distance is NaN
	///     or infinite.
	///   - ``Moon/ApsisError/apsisNotFound`` if there is none within the search, as for an
	///     ephemeris whose Moon doesn't move as the Moon does.
	public static func nextApsis<E: GeocentricEphemeris, Scale: Timescale>(_ kind: Moon.ApsisEvent.Kind, of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, ephemeris: E) throws(Moon.ApsisError) -> Moon.ApsisEvent {
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
				end = Instant(try from.julianDate.adding(days: Apsides.month))
			} catch {
				throw .invalidInterval
			}
			let found = try apsides(of: moon, from: from, to: end, context: TT.defaultContext, ephemeris: ephemeris, only: kind, stoppingAfterFirst: true).first
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
		throw .apsisNotFound
	}

	/// Returns the first perigee or apogee after an instant, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - kind: The apsis.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	/// - Returns: The apsis.
	/// - Throws: A ``Moon/ApsisError``, as the method taking an ephemeris does.
	public static func nextApsis<Scale: Timescale>(_ kind: Moon.ApsisEvent.Kind, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, precision: SeriesPrecision = .full) throws(Moon.ApsisError) -> Moon.ApsisEvent {
		try nextApsis(kind, of: BuiltInEphemeris.Body.moon, after: instant, context: context, ephemeris: BuiltInEphemeris(precision: precision))
	}
}
