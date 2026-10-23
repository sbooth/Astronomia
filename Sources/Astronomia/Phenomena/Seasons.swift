//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The equinoxes and solstices: the instants when the Sun's apparent geocentric ecliptic
/// longitude, in the true ecliptic and equinox of date, is 0°, 90°, 180°, or 270°.
///
/// The Sun's place is its apparent place seen from the center of the Earth, with light time,
/// aberration, and the gravitational deflection of light, converted to ``TrueEclipticOfDate``.
/// Each event is found to 0.1 s.
///
/// ```swift
/// let solstice = try Seasons.instant(of: .juneSolstice, year: 2026)
/// let events = try Seasons.events(from: start, to: end)
/// ```
///
/// The Sun's apparent longitude moves about 2.5" a minute, so an error of 1" in its place moves
/// an event by about 24 s. The methods taking the built-in ephemeris default to its full
/// precision, which places the Sun about a dozen times for each event, about 0.2 s in a
/// release build. The events from 1900 to 2049 are within 0.1 s of Skyfield's with DE421. The
/// Sun's own error is far smaller than the bound of a coarser ``Precision``: at
/// ``Precision/tenthArcsecond`` the same events are within 0.13 s, at about 40 ms each.
public enum Seasons {
	/// The precision of an event, 0.1 s, in days.
	static let tolerance = 0.1 / secondsPerDay
	/// The most evaluations to refine one event.
	static let maximumIterations = 100
	/// The Sun's mean motion in longitude, in radians per day, which predicts the next event.
	static let meanMotion = twoPi / 365.242_19
	/// The half-width of the bracket around a predicted event, in days.
	///
	/// The Sun's motion in longitude differs from its mean by under 3.5%, so a prediction
	/// across at most a quarter of a year is within about 3.2 days.
	static let margin = 5.0

	/// The Sun's apparent longitude at a time.
	struct Sample {
		/// The time, in days after the start of the interval.
		let time: Double
		/// The instant of the time.
		let instant: Instant<TT>
		/// The Sun's apparent longitude, in radians in [0, 2π).
		let longitude: Double
	}
}

extension Seasons {
	/// Returns the equinoxes and solstices in an interval, in order.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun and the Earth.
	/// - Returns: The events, in order of their instants.
	/// - Throws:
	///   - ``SeasonError/invalidInterval`` if `end` is before `start`.
	///   - ``SeasonError/timescaleConversion(_:)`` if the interval can't be converted to TT.
	///   - ``SeasonError/ephemeris(_:)`` if a place of the Sun in the interval fails, as for an
	///     ``Observation``, such as outside the ephemeris's coverage.
	public static func events<E: GeocentricEphemeris, Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(SeasonError) -> [SeasonEvent] {
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

		func evaluate(_ days: Double) throws(SeasonError) -> Sample {
			let instant: Instant<TT>
			if days >= length {
				instant = endTT
			} else {
				do throws(JulianDateError) {
					instant = Instant(try origin.adding(days: days))
				} catch {
					// A time between two representable instants is representable.
					throw .invalidInterval
				}
			}
			let place: ApparentPlace<ICRS>
			do throws(EphemerisError) {
				place = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris).apparentPlace(of: E.sun)
			} catch {
				throw .ephemeris(error)
			}
			let longitude = place.converted(to: TrueEclipticOfDate.self, earthOrientation: earthOrientation).position.spherical.longitude.radians
			return Sample(time: min(days, length), instant: instant, longitude: longitude)
		}
		/// Returns an angle reduced to (-π, π].
		func reduced(_ angle: Double) -> Double {
			let r = angle.remainder(dividingBy: twoPi)
			return r == -.pi ? .pi : r
		}

		var events: [SeasonEvent] = []
		var current = try evaluate(0)
		while current.time < length {
			// The next multiple of 90° after the current longitude, and when the Sun reaches it
			let index = Int((current.longitude / halfPi).rounded(.down)) + 1
			let target = Double(index) * halfPi
			let kind = SeasonEvent.Kind.allCases[index % 4]
			let predicted = current.time + (target - current.longitude) / meanMotion
			/// How far past the target the Sun is, negative before it.
			let past = { (sample: Sample) in reduced(sample.longitude - target) }

			// The bracket is the margin either side of the prediction, within the interval and
			// after the current time, which is before the event.
			var lower = current
			var upper: Sample? = nil
			if predicted - margin > current.time, predicted - margin < length {
				let sample = try evaluate(predicted - margin)
				if past(sample) < 0 {
					lower = sample
				} else {
					upper = sample
				}
			}
			if upper == nil {
				let sample = try evaluate(min(predicted + margin, length))
				guard past(sample) >= 0 else {
					// The event is after the end of the interval, or past the bracket, which the
					// Sun's motion doesn't allow but a custom ephemeris might.
					if sample.time >= length { break }
					current = sample
					continue
				}
				upper = sample
			}
			guard let upper else { break }
			let event = try RootFinder.refine(lower, upper, time: \.time, tolerance: tolerance, maximumIterations: maximumIterations, evaluate: evaluate, function: past)
			events.append(SeasonEvent(kind: kind, instant: event.instant))
			// The next event is a quarter of a year later.
			let next = event.time + 1
			guard next < length else { break }
			current = try evaluate(next)
		}
		return events
	}
}

extension Seasons {
	/// Returns the equinoxes and solstices in an interval, in order, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The events, in order of their instants.
	/// - Throws: A ``SeasonError``, as the method taking an ephemeris does.
	public static func events<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(SeasonError) -> [SeasonEvent] {
		try events(from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}

	/// Returns the instant of an equinox or a solstice in a year.
	///
	/// The search covers a few weeks around the event's usual date, so it evaluates the
	/// ephemeris for that event alone.
	///
	/// - Parameters:
	///   - kind: The equinox or solstice.
	///   - year: The year, in `calendar`.
	///   - calendar: The calendar of the year, by default ``CalendarIdentifier/julianGregorian``,
	///     the Julian calendar before October 15, 1582, and the Gregorian after.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun and the Earth.
	/// - Returns: The instant of the event.
	/// - Throws:
	///   - ``SeasonError/invalidYear`` if the year can't be represented in the calendar.
	///   - ``SeasonError/ephemeris(_:)`` if a place of the Sun fails, as for an
	///     ``Observation``, such as outside the ephemeris's coverage.
	public static func instant<E: GeocentricEphemeris>(of kind: SeasonEvent.Kind, year: Int, calendar: CalendarIdentifier = .julianGregorian, earthOrientation: EarthOrientation = .model, ephemeris: E) throws(SeasonError) -> Instant<TT> {
		let start: JulianDate
		let end: JulianDate
		do throws(CalendarError) {
			start = try JulianDate(year: year, month: 1, day: 1, calendar: calendar)
			end = try JulianDate(year: year + 1, month: 1, day: 1, calendar: calendar)
		} catch {
			throw .invalidYear
		}
		// The usual day of the year of each event, which the Julian calendar's drift and the
		// precession move by under three weeks between J1000.0 and J3000.0
		let usualDay = [79.0, 172, 265, 355][kind.index]
		let yearLength = end.daysSinceJ2000 - start.daysSinceJ2000
		let window = (from: max(0, usualDay - 30), to: min(yearLength, usualDay + 30))
		let from: JulianDate
		let to: JulianDate
		do throws(JulianDateError) {
			from = try start.adding(days: window.from)
			to = try start.adding(days: window.to)
		} catch {
			throw .invalidYear
		}
		let found = try events(from: Instant<TT>(from), to: Instant<TT>(to), earthOrientation: earthOrientation, ephemeris: ephemeris)
		guard let event = found.first(where: { $0.kind == kind }) else {
			// Each event falls within its window in every year the calendars and the
			// ephemeris cover.
			throw .invalidYear
		}
		return event.instant
	}

	/// Returns the instant of an equinox or a solstice in a year, with the built-in ephemeris.
	///
	/// - Parameters:
	///   - kind: The equinox or solstice.
	///   - year: The year, in `calendar`.
	///   - calendar: The calendar of the year, by default ``CalendarIdentifier/julianGregorian``.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	/// - Returns: The instant of the event.
	/// - Throws: A ``SeasonError``, as the method taking an ephemeris does.
	public static func instant(of kind: SeasonEvent.Kind, year: Int, calendar: CalendarIdentifier = .julianGregorian, earthOrientation: EarthOrientation = .model, precision: Precision = .full) throws(SeasonError) -> Instant<TT> {
		try instant(of: kind, year: year, calendar: calendar, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision))
	}
}
