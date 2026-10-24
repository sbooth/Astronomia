//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The eclipses of the Moon: penumbral, partial, and total, seen from the center of the Earth.
///
/// The Moon's and the Sun's places are their apparent places seen from the center of the
/// Earth, so the axis of the shadow is the direction opposite the apparent Sun. Each full Moon
/// near which the Moon is close enough to the axis is examined: the instant of greatest
/// eclipse, when the Moon's center is nearest the axis, is found to about 0.1 s, then each
/// contact of the Moon's limb with the penumbra or the umbra to 0.1 s.
///
/// ```swift
/// let eclipses = try LunarEclipses.events(from: start, to: end)
/// let next = try LunarEclipses.next(after: instant)
/// ```
///
/// The radii of the shadow follow a ``LunarEclipse/ShadowModel``, by default Danjon's, with
/// the Earth's equatorial radius of 6,378.137 km, the Sun's nominal radius of 695,700 km, and
/// the Moon's mean radius of 1,737.4 km.
///
/// The eclipses from 2001 to 2049 match NASA's Five Millennium Catalog of Lunar Eclipses,
/// computed with DE406 and Danjon's method: greatest eclipse within 1.6 s, gamma within
/// 0.0001, the magnitudes within 0.0007, and the lengths of the phases within 0.3 minutes, but
/// for a Moon grazing the edge of the penumbra or the umbra, whose phases change quickly with
/// its path. Each eclipse places the Sun and the Moon about 70 times, so at the built-in
/// ephemeris's full precision it takes about 1.5 s in a release build, and at
/// ``Precision/arcsecond``, which changes the magnitudes by under 0.001, about 60 ms.
public enum LunarEclipses {
	/// The most a full Moon is from the greatest eclipse near it, in days.
	///
	/// The Moon's path crosses the ecliptic at about 5°, so its center is nearest the axis of
	/// the shadow within about 25 minutes of the full Moon.
	static let fullMoonMargin: Double = 0.1
	/// The span either side of greatest eclipse that holds its contacts, in days.
	///
	/// The penumbral phase lasts at most about 6.3 hours.
	static let contactSpan: Double = 0.25
	/// The farthest the Moon's center is from the axis of the shadow, in radians, within
	/// ``fullMoonMargin`` of an eclipse's full Moon: under the penumbra's radius and the Moon's,
	/// at most about 1.6°, and the Moon's motion over the margin.
	static let nearAxis: Double = Angle(degrees: 3).radians
	/// The precision of greatest eclipse and of a contact, 0.1 s, in days.
	static let tolerance: Double = 0.1 / secondsPerDay
	/// The most lunations searched for the next eclipse, more than the longest span between
	/// eclipses of the Moon, of about six.
	static let maximumLunations: Int = 14
}

/// The geometry of the Moon and the Earth's shadow at a time.
struct LunarEclipseSample {
	/// The time, in days after the search's origin.
	let time: Double
	/// The instant of the time.
	let instant: Instant<TT>
	/// The angle between the Moon's center and the axis of the shadow, in radians.
	let separation: Double
	/// The squared distance between the directions of the Moon and the axis, which changes
	/// nearly as a parabola in time near greatest eclipse.
	let chordSquared: Double
	/// The radius of the penumbra, in radians.
	let penumbra: Double
	/// The radius of the umbra, in radians.
	let umbra: Double
	/// The Moon's radius, in radians.
	let moon: Double
	/// The Moon's equatorial horizontal parallax, in radians.
	let moonParallax: Double
	/// The direction of the Moon, in ICRS axes.
	let moonDirection: Vector3
	/// The direction of the axis of the shadow, in ICRS axes.
	let axisDirection: Vector3
}

/// Finds the eclipses of the Moon near full Moons, from samples at days after an origin.
struct LunarEclipseSearch<E: GeocentricEphemeris> {
	/// The instant from which the times of the search are counted.
	let origin: JulianDate
	/// The Moon.
	let moon: E.Body
	/// Observed Earth orientation.
	let earthOrientation: EarthOrientation
	/// The ephemeris.
	let ephemeris: E
	/// The model of the shadow.
	let shadowModel: LunarEclipse.ShadowModel

	/// Returns the instant some days after the origin.
	func instant(_ days: Double) throws(LunarEclipseError) -> Instant<TT> {
		do throws(JulianDateError) {
			return Instant(try origin.adding(days: days))
		} catch {
			throw .invalidInterval
		}
	}

	/// Returns the geometry of the Moon and the shadow some days after the origin.
	func sample(_ days: Double) throws(LunarEclipseError) -> LunarEclipseSample {
		let instant = try instant(days)
		let sun: Vector3
		let moonPosition: Vector3
		do throws(EphemerisError) {
			let sky = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
			sun = try sky.apparentPlace(of: E.sun).position.vector
			moonPosition = try sky.apparentPlace(of: moon).position.vector
		} catch {
			throw .ephemeris(error)
		}
		let (sunDistance, moonDistance) = (sun.length, moonPosition.length)
		guard sunDistance > 0, moonDistance > 0 else {
			throw .ephemeris(.invalidState)
		}
		let axis = sun / -sunDistance
		let direction = moonPosition / moonDistance
		let separation = Math.atan2(axis.cross(direction).length, axis.dot(direction))

		let earthRadius = earthEquatorialRadius.astronomicalUnits
		let moonParallax = Math.asin(min(1, earthRadius / moonDistance))
		let sunParallax = Math.asin(min(1, earthRadius / sunDistance))
		let sunRadius = Math.asin(min(1, nominalSolarRadius.astronomicalUnits / sunDistance))
		let moonRadius = Math.asin(min(1, lunarMeanRadius.astronomicalUnits / moonDistance))
		let penumbra: Double
		let umbra: Double
		switch shadowModel {
		case .danjon:
			penumbra = 1.01 * moonParallax + sunParallax + sunRadius
			umbra = 1.01 * moonParallax + sunParallax - sunRadius
		case .chauvenet:
			penumbra = 1.02 * (0.998_34 * moonParallax + sunParallax + sunRadius)
			umbra = 1.02 * (0.998_34 * moonParallax + sunParallax - sunRadius)
		}
		let chord = direction - axis
		return LunarEclipseSample(time: days, instant: instant, separation: separation, chordSquared: chord.dot(chord), penumbra: penumbra, umbra: umbra, moon: moonRadius, moonParallax: moonParallax, moonDirection: direction, axisDirection: axis)
	}

	/// Returns the full Moons from some days after the origin to others, in days after it.
	///
	/// - Parameter first: Whether to stop at the first.
	func fullMoons(from start: Double, to end: Double, first: Bool = false) throws(LunarEclipseError) -> [Double] {
		let (from, to) = (try instant(start), try instant(end))
		let events: [MoonPhaseEvent]
		do throws(MoonPhaseError) {
			events = try MoonPhases.events(of: moon, from: from, to: to, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: .fullMoon, stoppingAfterFirst: first)
		} catch {
			throw LunarEclipseError(error)
		}
		// The days between two Julian Dates, here of TT
		return events.map { Astrometry.days(from: Instant<TDB>(origin), to: Instant<TDB>($0.instant.julianDate)) }
	}

	/// Returns the sample of greatest eclipse near a time, where the Moon's center is nearest
	/// the axis of the shadow, and the Moon's speed across the shadow, in radians per day.
	///
	/// Near its least, the squared distance of the Moon's direction from the axis changes
	/// nearly as a parabola in time, exactly so for motion in a straight line, so the vertex of
	/// the parabola through three samples, each set closer around the last vertex, finds it
	/// to well under 0.1 s. The parabola's curvature, twice the square of the speed, gives the
	/// speed.
	func greatest(near time: Double) throws(LunarEclipseError) -> (sample: LunarEclipseSample, speed: Double) {
		var center = time
		var speed = 0.0
		for step in [0.05, 0.007, 0.000_7, 0.000_07] {
			let (before, at, after) = (try sample(center - step), try sample(center), try sample(center + step))
			let curvature = before.chordSquared - 2 * at.chordSquared + after.chordSquared
			guard curvature > 0 else { break }
			speed = (curvature / 2).squareRoot() / step
			let offset = step * (before.chordSquared - after.chordSquared) / (2 * curvature)
			center += max(-2 * step, min(2 * step, offset))
		}
		return (try sample(center), speed)
	}

	/// Returns the instant when the Moon's center is a radius from the axis of the shadow,
	/// before or after greatest eclipse, when it is within the radius.
	///
	/// The Moon's straight path across the shadow at its speed predicts the instant, which a
	/// bracket of 15 minutes either side holds; if it doesn't, as for a custom ephemeris, the
	/// bracket is the span from greatest eclipse.
	func contact(_ greatest: LunarEclipseSample, speed: Double, before: Bool, radius: @escaping (LunarEclipseSample) -> Double) throws(LunarEclipseError) -> Instant<TT> {
		let distance = { (sample: LunarEclipseSample) in sample.separation - radius(sample) }
		let sign = before ? -1.0 : 1.0
		// Half the chord of the Moon's path across the circle of the radius
		let (r, s) = (radius(greatest), greatest.separation)
		let half = max(0, r * r - s * s).squareRoot()
		let predicted = speed > 0 ? half / speed : LunarEclipses.contactSpan / 2
		let margin = 15.0 / 1440
		var near = greatest
		var far = try sample(greatest.time + sign * min(predicted + margin, LunarEclipses.contactSpan))
		if predicted > margin {
			let inside = try sample(greatest.time + sign * (predicted - margin))
			if distance(inside) < 0 {
				near = inside
			}
		}
		if distance(far) < 0 {
			far = try sample(greatest.time + sign * LunarEclipses.contactSpan)
			guard distance(far) >= 0 else {
				// The Moon's motion doesn't take it out of the shadow within the span, which a
				// custom ephemeris's might not.
				throw .eclipseNotFound
			}
		}
		let (lower, upper) = before ? (far, near) : (near, far)
		let found = try RootFinder.refine(lower, upper, time: \.time, tolerance: LunarEclipses.tolerance, maximumIterations: 100, evaluate: sample, function: distance)
		return found.instant
	}

	/// Returns the eclipse near a full Moon, or `nil` if there is none.
	func eclipse(nearFullMoon time: Double) throws(LunarEclipseError) -> LunarEclipse? {
		let full = try sample(time)
		// The Moon's center is nearest the axis within about 0.5% of its distance at full Moon.
		guard 0.99 * full.separation < full.penumbra + full.moon else {
			return nil
		}
		let (greatest, speed) = try greatest(near: time)
		guard greatest.separation < greatest.penumbra + greatest.moon else {
			return nil
		}
		let kind: LunarEclipse.Kind
		if greatest.separation < greatest.umbra - greatest.moon {
			kind = .total
		} else if greatest.separation < greatest.umbra + greatest.moon {
			kind = .partial
		} else {
			kind = .penumbral
		}
		let penumbralPhase = try contact(greatest, speed: speed, before: true) { $0.penumbra + $0.moon } ... contact(greatest, speed: speed, before: false) { $0.penumbra + $0.moon }
		var partialPhase: ClosedRange<Instant<TT>>? = nil
		if kind != .penumbral {
			partialPhase = try contact(greatest, speed: speed, before: true) { $0.umbra + $0.moon } ... contact(greatest, speed: speed, before: false) { $0.umbra + $0.moon }
		}
		var totalPhase: ClosedRange<Instant<TT>>? = nil
		if kind == .total {
			totalPhase = try contact(greatest, speed: speed, before: true) { $0.umbra - $0.moon } ... contact(greatest, speed: speed, before: false) { $0.umbra - $0.moon }
		}

		// Gamma is the distance from the axis in the plane through the Moon perpendicular to it,
		// in the Earth's radii, signed by the side of the axis in the true equator of date.
		let toDate = TrueEquatorOfDate.rotationFromICRS(at: greatest.instant, earthOrientation: earthOrientation)
		let axis = toDate.apply(to: greatest.axisDirection)
		let direction = toDate.apply(to: greatest.moonDirection)
		let north = direction.z - axis.z * direction.dot(axis)
		let gamma = Math.sin(greatest.separation) / Math.sin(greatest.moonParallax) * (north < 0 ? -1 : 1)
		let diameter = 2 * greatest.moon
		return LunarEclipse(kind: kind, greatestEclipse: greatest.instant, umbralMagnitude: (greatest.umbra + greatest.moon - greatest.separation) / diameter, penumbralMagnitude: (greatest.penumbra + greatest.moon - greatest.separation) / diameter, gamma: gamma, penumbralPhase: penumbralPhase, partialPhase: partialPhase, totalPhase: totalPhase, separation: Angle(radians: greatest.separation), penumbraRadius: Angle(radians: greatest.penumbra), umbraRadius: Angle(radians: greatest.umbra), moonRadius: Angle(radians: greatest.moon), shadowModel: shadowModel)
	}

	/// Returns the eclipses greatest from some days after the origin to others, in order.
	///
	/// The full Moons of the span are found, and those just outside it whose eclipses may be
	/// greatest within it, where the Moon is near the axis of the shadow at the span's start
	/// or end. The ephemeris is evaluated outside the span only for those, and for the contacts
	/// of an eclipse.
	func eclipses(from start: Double, to end: Double) throws(LunarEclipseError) -> [LunarEclipse] {
		var times = try fullMoons(from: start, to: end)
		if try sample(start).separation < LunarEclipses.nearAxis {
			times = try fullMoons(from: start - LunarEclipses.fullMoonMargin, to: start) + times
		}
		if try sample(end).separation < LunarEclipses.nearAxis {
			times += try fullMoons(from: end, to: end + LunarEclipses.fullMoonMargin)
		}
		var eclipses: [LunarEclipse] = []
		let (first, last) = (try instant(start), try instant(end))
		for time in times {
			guard let eclipse = try eclipse(nearFullMoon: time), eclipse.greatestEclipse >= first, eclipse.greatestEclipse <= last else {
				continue
			}
			// A full Moon at the start or the end of the span is found twice.
			if let previous = eclipses.last, abs(Astrometry.days(from: Instant<TDB>(previous.greatestEclipse.julianDate), to: Instant<TDB>(eclipse.greatestEclipse.julianDate))) < 1 {
				continue
			}
			eclipses.append(eclipse)
		}
		return eclipses
	}
}

extension LunarEclipses {
	/// Returns the eclipses of the Moon greatest in an interval, in order.
	///
	/// The ephemeris is evaluated up to about six hours outside the interval for an eclipse
	/// near its start or end, whose contacts may fall outside it.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipses, in order of their greatest eclipse.
	/// - Throws:
	///   - ``LunarEclipseError/invalidInterval`` if `end` is before `start`.
	///   - ``LunarEclipseError/timescaleConversion(_:)`` if the interval can't be converted to
	///     TT.
	///   - ``LunarEclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as outside the ephemeris's coverage.
	public static func events<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, shadowModel: LunarEclipse.ShadowModel = .danjon) throws(LunarEclipseError) -> [LunarEclipse] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			switch error {
			case .invalidInterval: throw .invalidInterval
			case let .timescaleConversion(error): throw .timescaleConversion(error)
			}
		}
		let search = LunarEclipseSearch(origin: interval.start.julianDate, moon: moon, earthOrientation: earthOrientation, ephemeris: ephemeris, shadowModel: shadowModel)
		return try search.eclipses(from: 0, to: interval.length)
	}

	/// Returns the eclipses of the Moon greatest in an interval, in order, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipses, in order of their greatest eclipse.
	/// - Throws: A ``LunarEclipseError``, as the method taking an ephemeris does.
	public static func events<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full, shadowModel: LunarEclipse.ShadowModel = .danjon) throws(LunarEclipseError) -> [LunarEclipse] {
		try events(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), shadowModel: shadowModel)
	}

	/// Returns the first eclipse of the Moon greatest after an instant.
	///
	/// The search steps from full Moon to full Moon, examining each, and stops at the eclipse.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipse.
	/// - Throws:
	///   - ``LunarEclipseError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``LunarEclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as for an eclipse past the ephemeris's coverage.
	///   - ``LunarEclipseError/eclipseNotFound`` if there is no eclipse within 14 lunations,
	///     as for an ephemeris whose Moon doesn't move as the Moon does.
	public static func next<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, shadowModel: LunarEclipse.ShadowModel = .danjon) throws(LunarEclipseError) -> LunarEclipse {
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let search = LunarEclipseSearch(origin: start.julianDate, moon: moon, earthOrientation: earthOrientation, ephemeris: ephemeris, shadowModel: shadowModel)
		// An eclipse greatest just after the instant may have its full Moon just before.
		if try search.sample(0).separation < nearAxis {
			for time in try search.fullMoons(from: -fullMoonMargin, to: 0) {
				if let eclipse = try search.eclipse(nearFullMoon: time), eclipse.greatestEclipse > start {
					return eclipse
				}
			}
		}
		var from = 0.0
		for _ in 0 ..< maximumLunations {
			guard let time = try search.fullMoons(from: from, to: from + MoonPhases.month, first: true).first else {
				break
			}
			if let eclipse = try search.eclipse(nearFullMoon: time), eclipse.greatestEclipse > start {
				return eclipse
			}
			from = time + 1
		}
		throw .eclipseNotFound
	}

	/// Returns the first eclipse of the Moon greatest after an instant, with the built-in
	/// ephemeris.
	///
	/// - Parameters:
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``Precision/full``.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipse.
	/// - Throws: A ``LunarEclipseError``, as the method taking an ephemeris does.
	public static func next<Scale: Timescale>(after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: Precision = .full, shadowModel: LunarEclipse.ShadowModel = .danjon) throws(LunarEclipseError) -> LunarEclipse {
		try next(of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), shadowModel: shadowModel)
	}
}
