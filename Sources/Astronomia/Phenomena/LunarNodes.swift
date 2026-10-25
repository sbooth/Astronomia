//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Moon's passages through the nodes of its orbit: the instants when the Moon's apparent
/// geocentric ecliptic latitude, in the true ecliptic and equinox of date, crosses zero,
/// northward at the ascending node and southward at the descending.
///
/// The Moon passes each node once a draconic month, about 27.2 days, and the two about 13.6
/// days apart. The nodes regress westward around the ecliptic once in about 18.6 years.
///
/// The Moon's place is its apparent place seen from the center of the Earth, with light time,
/// aberration, and the gravitational deflection of light, converted to ``TrueEclipticOfDate``,
/// as for ``MoonPhases``. Each passage is found to 0.1 s.
///
/// ```swift
/// let ascending = try LunarNodes.next(.ascending, after: instant)
/// let passages = try LunarNodes.events(from: start, to: end)
/// ```
///
/// The Moon's latitude changes by only about 0.05" a second at a node, so an error of 0.1" in
/// its place moves a passage by about 2 s. Each passage places the Moon about 17 times; the
/// methods taking the built-in ephemeris default to its full precision, at about 0.35 s each in
/// a release build. The passages from 2000 to 2049 are within 0.16 s, and their longitudes
/// within 0.09", of Skyfield's with DE421; at ``Precision/tenthArcsecond`` they are within 0.9 s
/// and 0.6", at about 60 ms each, and at ``Precision/arcsecond`` within 9 s and 6", at about
/// 18 ms each.
public enum LunarNodes {
	/// The time between the samples that bracket a passage, in days, less than the least time
	/// between passages, about 12.4 days.
	static let step: Double = 1
	/// The time after a passage before the next can be bracketed, in days: the least time
	/// between passages, less the step and a margin.
	static let skip: Double = 10
	/// The longest interval holding a passage through each node, a draconic month and a margin,
	/// in days.
	///
	/// Passages through a node are between about 27.0 and 27.5 days apart.
	static let month: Double = 30
}

extension LunarNodes {
	/// Returns the Moon's passages through its nodes in an interval, in order.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The passages, in order of their instants.
	/// - Throws:
	///   - ``LunarNodeError/invalidInterval`` if `end` is before `start`.
	///   - ``LunarNodeError/timescaleConversion(_:)`` if the interval can't be converted to TT.
	///   - ``LunarNodeError/ephemeris(_:)`` if a place of the Moon in the interval fails, as for
	///     an ``Observation``, such as outside the ephemeris's coverage.
	public static func events<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(LunarNodeError) -> [LunarNodeEvent] {
		try events(of: moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: ephemeris, only: nil, stoppingAfterFirst: false)
	}

	/// Returns the Moon's passages through one node or both in an interval, in order.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - kind: The only node to find, or `nil` for both. The others are bracketed, to step
	///     past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first passage found, without evaluating
	///     the ephemeris for the rest of the interval.
	/// - Returns: The passages, in order of their instants.
	/// - Throws: A ``LunarNodeError``, as the public method does.
	static func events<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context, earthOrientation: EarthOrientation, ephemeris: E, only kind: LunarNodeEvent.Kind?, stoppingAfterFirst: Bool) throws(LunarNodeError) -> [LunarNodeEvent] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			throw LunarNodeError(error)
		}
		/// Returns the Moon's apparent place in the true ecliptic of date some days after the
		/// start.
		func place(_ days: Double) throws(LunarNodeError) -> SphericalPosition<TrueEclipticOfDate> {
			let instant: Instant<TT>
			do throws(SearchInterval.Failure) {
				instant = try interval.instant(days)
			} catch {
				throw LunarNodeError(error)
			}
			do throws(EphemerisError) {
				let sky = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
				return try sky.apparentPlace(of: moon, in: TrueEclipticOfDate.self).position.spherical
			} catch {
				throw .ephemeris(error)
			}
		}
		let search = CrossingSearch(length: interval.length, step: step, skip: skip) { (days: Double) throws(LunarNodeError) -> Double in
			try place(days).latitude.radians
		}
		let rising = kind.map { $0 == .ascending }
		var events: [LunarNodeEvent] = []
		for crossing in try search.crossings(only: rising, stoppingAfterFirst: stoppingAfterFirst) {
			let instant: Instant<TT>
			do throws(SearchInterval.Failure) {
				instant = try interval.instant(crossing.time)
			} catch {
				throw LunarNodeError(error)
			}
			events.append(LunarNodeEvent(kind: crossing.isRising ? .ascending : .descending, instant: instant, longitude: try place(crossing.time).longitude))
		}
		return events
	}

	/// Returns the Moon's passages through its nodes in an interval, in order, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The passages, in order of their instants.
	/// - Throws: A ``LunarNodeError``, as the method taking an ephemeris does.
	public static func events<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(LunarNodeError) -> [LunarNodeEvent] {
		try events(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the first passage through a node after an instant.
	///
	/// The search covers at most a draconic month and a margin from the instant, stepping past
	/// a passage through the other node without refining it, and stops at the one found. A
	/// passage within 0.5 s of the instant, as when the instant is one found earlier, is taken
	/// as at it, not after it.
	///
	/// - Parameters:
	///   - kind: The node.
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	/// - Returns: The passage.
	/// - Throws:
	///   - ``LunarNodeError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``LunarNodeError/invalidInterval`` if the end of the search can't be represented.
	///   - ``LunarNodeError/ephemeris(_:)`` if a place of the Moon fails, as for an
	///     ``Observation``, such as past the ephemeris's coverage.
	///   - ``LunarNodeError/nodeNotFound`` if there is none within a draconic month and a margin
	///     after `instant`, as for an ephemeris whose Moon doesn't move as the Moon does.
	public static func next<E: GeocentricEphemeris, Scale: Timescale>(_ kind: LunarNodeEvent.Kind, of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(LunarNodeError) -> LunarNodeEvent {
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
				end = Instant(try from.julianDate.adding(days: month))
			} catch {
				throw .invalidInterval
			}
			let found = try events(of: moon, from: from, to: end, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: kind, stoppingAfterFirst: true).first
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
		throw .nodeNotFound
	}

	/// Returns the first passage through a node after an instant, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - kind: The node.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The passage.
	/// - Throws: A ``LunarNodeError``, as the method taking an ephemeris does.
	public static func next<Scale: Timescale>(_ kind: LunarNodeEvent.Kind, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(LunarNodeError) -> LunarNodeEvent {
		try next(kind, of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}
