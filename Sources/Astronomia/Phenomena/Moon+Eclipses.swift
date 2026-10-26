//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// The constants of the search for the eclipses of the Moon.
	enum Eclipses {
		/// The span either side of greatest eclipse that holds its contacts, in days.
		///
		/// The penumbral phase lasts at most about 6.3 hours.
		static let contactSpan: Double = 0.25
		/// The farthest the Moon's center is from the axis of the shadow, in radians, between an
		/// eclipse's full Moon and its greatest eclipse: the Moon's path crosses the ecliptic at
		/// about 5°, so they are within about 25 minutes, over which the Moon moves about 0.25°
		/// beyond the penumbra's radius and its own, at most about 1.6°.
		static let nearAxis: Double = Angle(degrees: 3).radians
		/// The precision of greatest eclipse and of a contact, 0.1 s, in days.
		static let tolerance: Double = 0.1 / secondsPerDay
		/// The interval within which an eclipse found by `next(after:)` is taken as at the
		/// instant, not after it, 0.5 s, in days.
		///
		/// An eclipse found earlier and found again from its greatest eclipse may be found a little
		/// later, within the precision of the two searches.
		static let sameEclipse: Double = 0.5 / secondsPerDay
		/// The most lunations searched for the next eclipse, more than the longest span between
		/// eclipses of the Moon, of about six.
		static let maximumLunations: Int = 14
		/// The most parabolas fit at each step to find greatest eclipse, each moving the time at
		/// most two steps, so a time up to 4 days from it, of the first step of 0.05 days, comes
		/// within a step of it.
		static let maximumFits: Int = 40
	}
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
	let shadowModel: Moon.Eclipse.ShadowModel

	/// Returns the instant some days after the origin.
	func instant(_ days: Double) throws(Moon.EclipseError) -> Instant<TT> {
		do throws(JulianDateError) {
			return Instant(try origin.adding(days: days))
		} catch {
			throw .invalidInterval
		}
	}

	/// Returns the geometry of the Moon and the shadow some days after the origin.
	func sample(_ days: Double) throws(Moon.EclipseError) -> LunarEclipseSample {
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
	func fullMoons(from start: Double, to end: Double, first: Bool = false) throws(Moon.EclipseError) -> [Double] {
		let (from, to) = (try instant(start), try instant(end))
		let events: [Moon.PhaseEvent]
		do throws(Moon.PhaseError) {
			events = try Moon.phases(of: moon, from: from, to: to, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: .fullMoon, stoppingAfterFirst: first)
		} catch {
			throw Moon.EclipseError(error)
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
	/// to well under 0.1 s. At each step the parabolas are fit again until the vertex is within
	/// the step, before the step shrinks, so a time hours from greatest eclipse, as at the end
	/// of an interval, converges on it. The parabola's curvature, twice the square of the
	/// speed, gives the speed. A step whose samples the ephemeris doesn't cover is halved until
	/// they are.
	func greatest(near time: Double) throws(Moon.EclipseError) -> (sample: LunarEclipseSample, speed: Double) {
		var center = time
		var speed = 0.0
		let smallest = 0.000_07
		for nominal in [0.05, 0.007, 0.000_7, smallest] {
			var step = nominal
			for _ in 0 ..< Moon.Eclipses.maximumFits {
				var samples: (before: LunarEclipseSample, at: LunarEclipseSample, after: LunarEclipseSample)
				while true {
					do throws(Moon.EclipseError) {
						samples = (try sample(center - step), try sample(center), try sample(center + step))
						break
					} catch {
						// Where the ephemeris doesn't cover the samples of a step, as for an
						// eclipse just within the end of its coverage, a closer step may be.
						guard step > smallest else {
							throw error
						}
						step /= 2
					}
				}
				let (before, at, after) = samples
				let curvature = before.chordSquared - 2 * at.chordSquared + after.chordSquared
				guard curvature > 0 else {
					// Not near a least, which a straight path always is: move downhill.
					center += before.chordSquared < after.chordSquared ? -2 * step : 2 * step
					continue
				}
				speed = (curvature / 2).squareRoot() / step
				let offset = step * (before.chordSquared - after.chordSquared) / (2 * curvature)
				center += max(-2 * step, min(2 * step, offset))
				if abs(offset) <= step {
					break
				}
			}
		}
		return (try sample(center), speed)
	}

	/// Returns the instant when the Moon's center is a radius from the axis of the shadow,
	/// before or after greatest eclipse, when it is within the radius.
	///
	/// The Moon's straight path across the shadow at its speed predicts the instant, which a
	/// bracket of 15 minutes either side holds; if it doesn't, as for a custom ephemeris, the
	/// bracket is the span from greatest eclipse. The end of the bracket outside the shadow
	/// closes on the contact where the ephemeris doesn't cover it.
	func contact(_ greatest: LunarEclipseSample, speed: Double, before: Bool, radius: @escaping (LunarEclipseSample) -> Double) throws(Moon.EclipseError) -> Instant<TT> {
		let distance = { (sample: LunarEclipseSample) in sample.separation - radius(sample) }
		let sign = before ? -1.0 : 1.0
		// Half the chord of the Moon's path across the circle of the radius
		let (r, s) = (radius(greatest), greatest.separation)
		let half = max(0, r * r - s * s).squareRoot()
		let predicted = speed > 0 ? half / speed : Moon.Eclipses.contactSpan / 2
		let margin = 15.0 / 1440
		var near = greatest
		if predicted > margin {
			let inside = try sample(greatest.time + sign * (predicted - margin))
			if distance(inside) < 0 {
				near = inside
			}
		}
		var bracket = try outside(from: near, at: greatest.time + sign * min(predicted + margin, Moon.Eclipses.contactSpan), distance: distance)
		if bracket.far == nil {
			bracket = try outside(from: bracket.near, at: greatest.time + sign * Moon.Eclipses.contactSpan, distance: distance)
		}
		guard let far = bracket.far else {
			// The Moon's motion doesn't take it out of the shadow within the span, which a
			// custom ephemeris's might not.
			throw .eclipseNotFound
		}
		near = bracket.near
		let (lower, upper) = before ? (far, near) : (near, far)
		let found = try RootFinder.refine(lower, upper, time: \.time, tolerance: Moon.Eclipses.tolerance, maximumIterations: 100, evaluate: sample, function: distance)
		return found.instant
	}

	/// Returns a sample outside a circle about the axis, after a sample inside it, toward a
	/// time.
	///
	/// Where the ephemeris doesn't cover the time, as past the end of its coverage, the time
	/// moves back halfway to the latest time inside the circle, until a sample outside is
	/// found, or the failing times come within the tolerance of one inside, when the failure
	/// is thrown, as ``QuarterSearch`` closes a bracket.
	///
	/// - Parameters:
	///   - near: A sample inside the circle.
	///   - time: The time of the outer end of the bracket.
	///   - distance: The distance of a sample outside the circle, negative inside.
	/// - Returns: The latest sample inside the circle, and a sample outside it, or `nil` if the
	///   sample at `time` is inside.
	func outside(from near: LunarEclipseSample, at time: Double, distance: (LunarEclipseSample) -> Double) throws(Moon.EclipseError) -> (near: LunarEclipseSample, far: LunarEclipseSample?) {
		var near = near
		var time = time
		var failed: Double? = nil
		while true {
			do throws(Moon.EclipseError) {
				let sample = try sample(time)
				if distance(sample) >= 0 {
					return (near, sample)
				}
				guard let failed else {
					return (sample, nil)
				}
				near = sample
				time = (near.time + failed) / 2
			} catch {
				guard abs(time - near.time) > Moon.Eclipses.tolerance else {
					throw error
				}
				failed = time
				time = (near.time + time) / 2
			}
		}
	}

	/// Returns the eclipse near a time, or `nil` if there is none.
	///
	/// - Parameters:
	///   - time: The time, a full Moon or near the eclipse.
	///   - isFullMoon: Whether the time is a full Moon, at which the Moon's center is within
	///     about 0.5% of its least distance from the axis, so a full Moon farther from it than
	///     the penumbra and the Moon's radii has no eclipse.
	func eclipse(near time: Double, isFullMoon: Bool = true) throws(Moon.EclipseError) -> Moon.Eclipse? {
		if isFullMoon {
			let full = try sample(time)
			guard 0.99 * full.separation < full.penumbra + full.moon else {
				return nil
			}
		}
		let (greatest, speed) = try greatest(near: time)
		guard greatest.separation < greatest.penumbra + greatest.moon else {
			return nil
		}
		let kind: Moon.Eclipse.Kind
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
		return Moon.Eclipse(kind: kind, greatestEclipse: greatest.instant, umbralMagnitude: (greatest.umbra + greatest.moon - greatest.separation) / diameter, penumbralMagnitude: (greatest.penumbra + greatest.moon - greatest.separation) / diameter, gamma: gamma, penumbralPhase: penumbralPhase, partialPhase: partialPhase, totalPhase: totalPhase, separation: Angle(radians: greatest.separation), penumbraRadius: Angle(radians: greatest.penumbra), umbraRadius: Angle(radians: greatest.umbra), moonRadius: Angle(radians: greatest.moon), shadowModel: shadowModel)
	}

	/// Returns the eclipses greatest from some days after the origin to others, in order.
	///
	/// The full Moons of the span are examined, and where the Moon is near the axis of the
	/// shadow at the span's start or end, the eclipse there, which may be greatest within the
	/// span though its full Moon is outside it. The ephemeris is evaluated outside the span
	/// only for such an eclipse, and for the contacts of an eclipse.
	func eclipses(from start: Double, to end: Double) throws(Moon.EclipseError) -> [Moon.Eclipse] {
		var times = try fullMoons(from: start, to: end).map { (time: $0, isFullMoon: true) }
		if try sample(start).separation < Moon.Eclipses.nearAxis {
			times.insert((start, false), at: 0)
		}
		if try sample(end).separation < Moon.Eclipses.nearAxis {
			times.append((end, false))
		}
		var eclipses: [Moon.Eclipse] = []
		let (first, last) = (try instant(start), try instant(end))
		for (time, isFullMoon) in times {
			guard let eclipse = try eclipse(near: time, isFullMoon: isFullMoon), eclipse.greatestEclipse >= first, eclipse.greatestEclipse <= last else {
				continue
			}
			// An eclipse at the start or the end of the span may be found twice.
			if let previous = eclipses.last, abs(Astrometry.days(from: Instant<TDB>(previous.greatestEclipse.julianDate), to: Instant<TDB>(eclipse.greatestEclipse.julianDate))) < 1 {
				continue
			}
			eclipses.append(eclipse)
		}
		return eclipses
	}
}

extension Moon {
	/// Returns the eclipses of the Moon greatest in an interval, in order.
	///
	/// The Moon's and the Sun's places are their apparent places seen from the center of the
	/// Earth, so the axis of the shadow is the direction opposite the apparent Sun. Each full Moon
	/// near which the Moon is close enough to the axis is examined: the instant of greatest
	/// eclipse, when the Moon's center is nearest the axis, is found to about 0.1 s, then each
	/// contact of the Moon's limb with the penumbra or the umbra to 0.1 s.
	///
	/// ```swift
	/// let eclipses = try Moon.eclipses(from: start, to: end)
	/// let next = try Moon.nextEclipse(after: instant)
	/// ```
	///
	/// The radii of the shadow follow a ``Moon/Eclipse/ShadowModel``, by default Danjon's, with
	/// the Earth's equatorial radius of 6,378.137 km, the Sun's nominal radius of 695,700 km, and
	/// the Moon's mean radius of 1,737.4 km.
	///
	/// The eclipses from 2001 to 2049 match NASA's Five Millennium Catalog of Lunar Eclipses,
	/// computed with DE406 and Danjon's method: greatest eclipse within 1.6 s, gamma within
	/// 0.0001, the magnitudes within 0.0007, and the lengths of the phases within 0.3 minutes, but
	/// for a Moon grazing the edge of the penumbra or the umbra, whose phases change quickly with
	/// its path. Each eclipse places the Sun and the Moon about 70 times, so at the built-in
	/// ephemeris's full precision it takes about 1.5 s in a release build, and at
	/// ``SeriesPrecision/arcsecond``, which changes the magnitudes by under 0.001, about 60 ms.
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
	///   - ``Moon/EclipseError/invalidInterval`` if `end` is before `start`.
	///   - ``Moon/EclipseError/timescaleConversion(_:)`` if the interval can't be converted to
	///     TT.
	///   - ``Moon/EclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as outside the ephemeris's coverage.
	public static func eclipses<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> [Moon.Eclipse] {
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
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipses, in order of their greatest eclipse.
	/// - Throws: A ``Moon/EclipseError``, as the method taking an ephemeris does.
	public static func eclipses<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> [Moon.Eclipse] {
		try eclipses(of: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), shadowModel: shadowModel)
	}

	/// Returns the first eclipse of the Moon greatest after an instant.
	///
	/// The search steps from full Moon to full Moon, examining each, and stops at the eclipse.
	/// An eclipse greatest within 0.5 s of the instant, as when the instant is the greatest
	/// eclipse of one found earlier, is taken as at it, not after it.
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
	///   - ``Moon/EclipseError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``Moon/EclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as for an eclipse past the ephemeris's coverage.
	///   - ``Moon/EclipseError/eclipseNotFound`` if there is no eclipse within 14 lunations,
	///     as for an ephemeris whose Moon doesn't move as the Moon does.
	public static func nextEclipse<E: GeocentricEphemeris, Scale: Timescale>(of moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> Moon.Eclipse {
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let search = LunarEclipseSearch(origin: start.julianDate, moon: moon, earthOrientation: earthOrientation, ephemeris: ephemeris, shadowModel: shadowModel)
		/// Whether an eclipse is greatest after the instant, not within `Eclipses.sameEclipse` of
		/// it, as when the instant is an eclipse found earlier
		func isAfter(_ eclipse: Moon.Eclipse) -> Bool {
			Astrometry.days(from: Instant<TDB>(start.julianDate), to: Instant<TDB>(eclipse.greatestEclipse.julianDate)) > Eclipses.sameEclipse
		}
		// An eclipse greatest just after the instant may have its full Moon just before.
		if try search.sample(0).separation < Eclipses.nearAxis, let eclipse = try search.eclipse(near: 0, isFullMoon: false), isAfter(eclipse) {
			return eclipse
		}
		var from = 0.0
		for _ in 0 ..< Eclipses.maximumLunations {
			guard let time = try search.fullMoons(from: from, to: from + Moon.Phases.month, first: true).first else {
				break
			}
			if let eclipse = try search.eclipse(near: time), isAfter(eclipse) {
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
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	///   - shadowModel: The model of the Earth's shadow, by default Danjon's.
	/// - Returns: The eclipse.
	/// - Throws: A ``Moon/EclipseError``, as the method taking an ephemeris does.
	public static func nextEclipse<Scale: Timescale>(after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full, shadowModel: Moon.Eclipse.ShadowModel = .danjon) throws(Moon.EclipseError) -> Moon.Eclipse {
		try nextEclipse(of: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), shadowModel: shadowModel)
	}
}
