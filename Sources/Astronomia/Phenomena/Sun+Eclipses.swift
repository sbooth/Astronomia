//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Sun {
	/// The constants of the search for the eclipses of the Sun.
	enum Eclipses {
		/// The span either side of greatest eclipse that holds its contacts, in days.
		///
		/// The penumbra is on the Earth for at most about 6.3 hours.
		static let contactSpan: Double = 0.25
		/// The step from greatest eclipse that brackets a contact, 30 minutes, in days.
		static let step: Double = 1.0 / 48
		/// The farthest the axis of the shadow is from the Earth's center, in equatorial radii of
		/// the Earth, between an eclipse's new Moon and its greatest eclipse: they are within
		/// about 25 minutes, over which the axis moves about 0.3 radii beyond the penumbra's
		/// radius, about 0.57, and the Earth's, at most about 1.9.
		static let nearAxis: Double = 3
		/// The precision of greatest eclipse and of a contact, 0.1 s, in days.
		static let tolerance: Double = 0.1 / secondsPerDay
		/// The interval within which an eclipse found by `nextEclipse(after:)` is taken as at the
		/// instant, not after it, 0.5 s, in days.
		static let sameEclipse: Double = 0.5 / secondsPerDay
		/// The most lunations searched for the next eclipse, more than the longest span between
		/// eclipses of the Sun, of about six.
		static let maximumLunations: Int = 14
		/// The number of spans of the central line between its ends at which the kind of a
		/// central eclipse is found, besides greatest eclipse and the ends.
		static let centralSpans: Int = 8
		/// The most parabolas fit at each step to find greatest eclipse, each moving the time at
		/// most two steps, so a time up to 4 days from it, of the first step of 0.05 days, comes
		/// within a step of it.
		static let maximumFits: Int = 40
	}
}

/// The geometry of the Moon's shadow and the Earth at a time, on the fundamental plane through
/// the Earth's center perpendicular to the axis of the shadow, in equatorial radii of the Earth.
struct SolarEclipseSample {
	/// The time, in days after the search's origin.
	let time: Double
	/// The instant of the time.
	let instant: Instant<TT>
	/// The coordinate of the axis toward the east, along the true equator of date.
	let x: Double
	/// The coordinate of the axis toward the north.
	let y: Double
	/// The Moon's coordinate along the axis, positive toward the Sun, where the Moon is between
	/// the Earth and the Sun, and negative where it is beyond the Earth, as at full Moon.
	let z: Double
	/// The declination of the axis, toward the Sun, in the true equator of date, in radians.
	let declination: Double
	/// The direction of the axis toward the Sun, in the axes of the true equator of date.
	let axis: Vector3
	/// The direction of the plane's x axis, toward the east.
	let east: Vector3
	/// The direction of the plane's y axis, toward the north.
	let north: Vector3
	/// The semiaxis of the Earth's outline on the plane toward the north, ρ₁.
	let rho1: Double
	/// The radius of the penumbra.
	let l1: Double
	/// The radius of the umbra, negative beyond its vertex, where the shadow is the antumbra
	/// and the radius is the antumbra's, positive.
	let l2: Double
	/// The tangent of the half-angle of the penumbra's cone.
	let tanF1: Double
	/// The tangent of the half-angle of the umbra's cone.
	let tanF2: Double
	/// The distance of the axis from the Earth's outline, negative within it.
	let edge: Double
	/// The height above the plane of the point where the axis meets the Earth, toward the Sun,
	/// or `nil` if it doesn't.
	let zeta: Double?

	/// The squared distance of the axis from the Earth's center.
	var centerSquared: Double {
		x * x + y * y
	}

	/// The radius of the umbra, or of the antumbra, positive, at the height of the point where
	/// the axis meets the Earth, negative where the shadow is the umbra.
	///
	/// - Precondition: The axis meets the Earth.
	var surfaceL2: Double {
		l2 - (zeta ?? 0) * tanF2
	}

	/// The radius of the penumbra at the height of the point where the axis meets the Earth.
	var surfaceL1: Double {
		l1 - (zeta ?? 0) * tanF1
	}
}

/// Returns the signed distance of a point from an ellipse centered at the origin, with a
/// semiaxis of 1 along x and of `b` along y, positive outside it.
///
/// - Parameters:
///   - x: The point's x.
///   - y: The point's y.
///   - b: The semiaxis along y, near 1.
func signedDistanceFromEllipse(x: Double, y: Double, b: Double) -> Double {
	nearestPointOfEllipse(x: x, y: y, b: b).distance
}

/// Returns the point of an ellipse centered at the origin, with a semiaxis of 1 along x and of
/// `b` along y, nearest a point, and the signed distance of the point from it, positive outside
/// the ellipse.
///
/// The nearest point, at the angle θ of the ellipse's parametric form (cos θ, b sin θ), is
/// found by Newton's method from the point's own angle, which for an ellipse nearly a circle,
/// as the Earth's outline, is close to it.
///
/// - Parameters:
///   - x: The point's x.
///   - y: The point's y.
///   - b: The semiaxis along y, near 1.
func nearestPointOfEllipse(x: Double, y: Double, b: Double) -> (x: Double, y: Double, distance: Double) {
	let flattening = 1 - b * b
	var theta = Math.atan2(y, x)
	for _ in 0 ..< 8 {
		let (sin, cos) = (Math.sin(theta), Math.cos(theta))
		// The derivative of half the squared distance, and its derivative
		let slope = x * sin - b * y * cos - flattening * sin * cos
		let curvature = x * cos + b * y * sin - flattening * (cos * cos - sin * sin)
		guard curvature != 0 else { break }
		let change = slope / curvature
		theta -= change
		guard abs(change) > 1e-15 else { break }
	}
	let (nearestX, nearestY) = (Math.cos(theta), b * Math.sin(theta))
	let (dx, dy) = (x - nearestX, y - nearestY)
	let distance = (dx * dx + dy * dy).squareRoot()
	return (nearestX, nearestY, x * x + (y / b) * (y / b) < 1 ? -distance : distance)
}

/// Finds the eclipses of the Sun near new Moons, from samples at days after an origin.
struct SolarEclipseSearch<E: GeocentricEphemeris> {
	/// The instant from which the times of the search are counted.
	let origin: JulianDate
	/// The Moon.
	let moon: E.Body
	/// Observed Earth orientation.
	let earthOrientation: EarthOrientation
	/// The ephemeris.
	let ephemeris: E
	/// The radii of the Moon and the Sun.
	let radii: Sun.Eclipse.Radii

	/// Returns the instant some days after the origin.
	func instant(_ days: Double) throws(Sun.EclipseError) -> Instant<TT> {
		do throws(JulianDateError) {
			return Instant(try origin.adding(days: days))
		} catch {
			throw .invalidInterval
		}
	}

	/// Returns the geometry of the shadow and the Earth some days after the origin.
	///
	/// The axis of the shadow runs from the Moon toward the Sun, from their apparent places seen
	/// from the Earth's center, in the axes of the true equator of date, whose pole is the
	/// Earth's axis of figure. Its coordinates on the fundamental plane are those of the
	/// Moon's center, and the radii of the cones those at the plane, from the Moon's and the
	/// Sun's radii. The Earth's outline on the plane is the WGS84 ellipsoid seen along the axis,
	/// an ellipse with a semiaxis of 1 toward the east and of ρ₁ = √(1 - e² cos² d) toward the
	/// north, for the axis's declination d.
	func sample(_ days: Double) throws(Sun.EclipseError) -> SolarEclipseSample {
		let instant = try instant(days)
		let sunPosition: Vector3
		let moonPosition: Vector3
		do throws(EphemerisError) {
			let sky = try Observer.geocenter.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
			sunPosition = try sky.apparentPlace(of: E.sun).position.vector
			moonPosition = try sky.apparentPlace(of: moon).position.vector
		} catch {
			throw .ephemeris(error)
		}
		let toDate = TrueEquatorOfDate.rotationFromICRS(at: instant, earthOrientation: earthOrientation)
		let earthRadius = earthEquatorialRadius.astronomicalUnits
		let sun = toDate.apply(to: sunPosition) / earthRadius
		let moon = toDate.apply(to: moonPosition) / earthRadius
		let axis = sun - moon
		let distance = axis.length
		let east = Vector3(-axis.y, axis.x, 0)
		guard distance.isFinite, distance > 0, east.length > 0 else {
			throw .ephemeris(.invalidState)
		}
		let g = axis / distance
		let xAxis = east / east.length
		let yAxis = g.cross(xAxis)
		let (x, y, z) = (moon.dot(xAxis), moon.dot(yAxis), moon.dot(g))

		// The cones' half-angles, from the radii of the Sun and the Moon and their distance
		let sunRadius = Math.sin(radii.sun.radians) / earthRadius
		let sinF1 = (sunRadius + radii.penumbralMoon) / distance
		let sinF2 = (sunRadius - radii.umbralMoon) / distance
		guard sinF1 < 1, sinF2 > -1 else {
			throw .ephemeris(.invalidState)
		}
		let (cosF1, cosF2) = ((1 - sinF1 * sinF1).squareRoot(), (1 - sinF2 * sinF2).squareRoot())
		let (tanF1, tanF2) = (sinF1 / cosF1, sinF2 / cosF2)
		let l1 = z * tanF1 + radii.penumbralMoon / cosF1
		let l2 = z * tanF2 - radii.umbralMoon / cosF2

		let flattening = Ellipsoid.wgs84.flattening
		let eccentricitySquared = flattening * (2 - flattening)
		let rho1 = (1 - eccentricitySquared * (1 - g.z * g.z)).squareRoot()
		let edge = signedDistanceFromEllipse(x: x, y: y, b: rho1)

		// Where the axis meets the ellipsoid X² + Y² + Z²/(1 - f)² = 1, the root toward the Sun
		// of |p + ζg|² with Z scaled, for the axis's point p on the plane
		var zeta: Double? = nil
		if edge <= 0 {
			let polarSquared = (1 - flattening) * (1 - flattening)
			let p = x * xAxis + y * yAxis
			let a = g.x * g.x + g.y * g.y + g.z * g.z / polarSquared
			let b = p.x * g.x + p.y * g.y + p.z * g.z / polarSquared
			let c = p.x * p.x + p.y * p.y + p.z * p.z / polarSquared - 1
			let discriminant = b * b - a * c
			if discriminant >= 0 {
				zeta = (-b + discriminant.squareRoot()) / a
			}
		}
		return SolarEclipseSample(time: days, instant: instant, x: x, y: y, z: z, declination: Math.asin(g.z), axis: g, east: xAxis, north: yAxis, rho1: rho1, l1: l1, l2: l2, tanF1: tanF1, tanF2: tanF2, edge: edge, zeta: zeta)
	}

	/// Returns the new Moons from some days after the origin to others, in days after it.
	///
	/// - Parameter first: Whether to stop at the first.
	func newMoons(from start: Double, to end: Double, first: Bool = false) throws(Sun.EclipseError) -> [Double] {
		let (from, to) = (try instant(start), try instant(end))
		let events: [Moon.PhaseEvent]
		do throws(Moon.PhaseError) {
			events = try Moon.phases(of: moon, from: from, to: to, context: TT.defaultContext, earthOrientation: earthOrientation, ephemeris: ephemeris, only: .newMoon, stoppingAfterFirst: first)
		} catch {
			throw Sun.EclipseError(error)
		}
		// The days between two Julian Dates, here of TT
		return events.map { Astrometry.days(from: Instant<TDB>(origin), to: Instant<TDB>($0.instant.julianDate)) }
	}

	/// Returns the sample of greatest eclipse near a time, where the axis of the shadow is
	/// nearest the Earth's center, and the speed of the axis across the fundamental plane, in
	/// equatorial radii of the Earth per day.
	///
	/// Near its least, the squared distance of the axis from the center changes nearly as a
	/// parabola in time, exactly so for motion in a straight line, so the vertex of the parabola
	/// through three samples, each set closer around the last vertex, finds it to well under
	/// 0.1 s. At each step the parabolas are fit again until the vertex is within the step,
	/// before the step shrinks, so a time hours from greatest eclipse, as at the end of an
	/// interval, converges on it. The parabola's curvature, twice the square of the speed, gives
	/// the speed. A step whose samples the ephemeris doesn't cover is halved until they are.
	func greatest(near time: Double) throws(Sun.EclipseError) -> (sample: SolarEclipseSample, speed: Double) {
		var center = time
		var speed = 0.0
		let smallest = 0.000_07
		for nominal in [0.05, 0.007, 0.000_7, smallest] {
			var step = nominal
			for _ in 0 ..< Sun.Eclipses.maximumFits {
				var samples: (before: SolarEclipseSample, at: SolarEclipseSample, after: SolarEclipseSample)
				while true {
					do throws(Sun.EclipseError) {
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
				let curvature = before.centerSquared - 2 * at.centerSquared + after.centerSquared
				guard curvature > 0 else {
					// Not near a least, which a straight path always is: move downhill.
					center += before.centerSquared < after.centerSquared ? -2 * step : 2 * step
					continue
				}
				speed = (curvature / 2).squareRoot() / step
				let offset = step * (before.centerSquared - after.centerSquared) / (2 * curvature)
				center += max(-2 * step, min(2 * step, offset))
				if abs(offset) <= step {
					break
				}
			}
		}
		return (try sample(center), speed)
	}

	/// Returns the sample at a contact before or after greatest eclipse, where a function of the
	/// samples, negative at greatest eclipse, crosses zero, when the axis is a distance from the
	/// Earth's outline.
	///
	/// The axis's straight path across the fundamental plane at its speed predicts the instant,
	/// taking the Earth's outline as a circle of radius 1, which a bracket of 10 minutes either
	/// side holds; where it doesn't, as for a custom ephemeris, samples a step apart from the
	/// bracket's inner end bracket the contact, which ``RootFinder`` finds to 0.1 s. Where the
	/// ephemeris doesn't cover a sample, as past the end of its coverage, the step halves toward
	/// the last sample, as ``QuarterSearch`` closes a bracket, until the contact is bracketed or
	/// the failing time comes within the tolerance.
	///
	/// - Parameters:
	///   - greatest: The sample of greatest eclipse.
	///   - speed: The speed of the axis, in equatorial radii of the Earth per day.
	///   - distance: The distance of the axis from the Earth's outline at the contact, about.
	///   - before: Whether the contact is before greatest eclipse.
	///   - function: The function, negative at greatest eclipse and nonnegative past the contact.
	func contact(_ greatest: SolarEclipseSample, speed: Double, distance: Double, before: Bool, function: @escaping (SolarEclipseSample) -> Double) throws(Sun.EclipseError) -> SolarEclipseSample {
		let sign = before ? -1.0 : 1.0
		var near = greatest
		var failed: Double? = nil
		var time = greatest.time + sign * Sun.Eclipses.step
		// Half the chord of the axis's path across the circle of the Earth's radius and the
		// distance
		let half = max(0, (1 + distance) * (1 + distance) - greatest.centerSquared).squareRoot()
		let margin = 10.0 / 1440
		if speed > 0, half / speed < Sun.Eclipses.contactSpan {
			let predicted = half / speed
			if predicted > margin {
				let inside = try sample(greatest.time + sign * (predicted - margin))
				if function(inside) < 0 {
					near = inside
				}
			}
			time = greatest.time + sign * (predicted + margin)
		}
		let far: SolarEclipseSample
		while true {
			guard abs(time - greatest.time) <= Sun.Eclipses.contactSpan + Sun.Eclipses.step else {
				// The shadow doesn't leave the Earth within the span, which a custom ephemeris's
				// might not.
				throw .eclipseNotFound
			}
			do throws(Sun.EclipseError) {
				let sample = try sample(time)
				if function(sample) >= 0 {
					far = sample
					break
				}
				near = sample
				time = failed.map { (near.time + $0) / 2 } ?? near.time + sign * Sun.Eclipses.step
			} catch {
				guard abs(time - near.time) > Sun.Eclipses.tolerance else {
					throw error
				}
				failed = time
				time = (near.time + time) / 2
			}
		}
		let (lower, upper) = before ? (far, near) : (near, far)
		return try RootFinder.refine(lower, upper, time: \.time, tolerance: Sun.Eclipses.tolerance, maximumIterations: 100, evaluate: sample, function: function)
	}

	/// The rotations that place a point of the Earth at an instant: from the ICRS to the true
	/// equator of date, the axes of the samples, and to the ITRS.
	struct EarthFrames {
		/// The rotation from the ICRS to the true equator of date.
		let toDate: Rotation<ICRS, TrueEquatorOfDate>
		/// The rotation from the ICRS to the ITRS.
		let toITRS: Rotation<ICRS, ITRS>

		/// Returns a vector of the true equator of date in the ITRS.
		func itrs(fromDate vector: Vector3) -> Vector3 {
			toITRS.apply(to: toDate.applyInverse(to: vector))
		}

		/// Returns a vector of the ITRS in the true equator of date.
		func date(fromITRS vector: Vector3) -> Vector3 {
			toDate.apply(to: toITRS.applyInverse(to: vector))
		}
	}

	/// Returns the rotations that place a point of the Earth at an instant.
	func earthFrames(at instant: Instant<TT>) throws(Sun.EclipseError) -> EarthFrames {
		let ut1: Instant<UT1>
		do throws(TimescaleConversionError) {
			ut1 = try instant.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		} catch {
			throw .timescaleConversion(error)
		}
		return EarthFrames(toDate: TrueEquatorOfDate.rotationFromICRS(at: instant, earthOrientation: earthOrientation), toITRS: ITRS.rotationFromICRS(at: instant, ut1: ut1, earthOrientation: earthOrientation))
	}

	/// The position of a point of the Earth relative to the shadow at a time.
	struct GroundSample {
		/// The time, in days after the search's origin.
		let time: Double
		/// The instant of the time.
		let instant: Instant<TT>
		/// The point's coordinates on the fundamental plane relative to the axis, in equatorial
		/// radii of the Earth.
		let offset: (x: Double, y: Double)
		/// The distance of the point from the edge of the umbra or the antumbra, at its height,
		/// on the plane, negative within it.
		let umbralDistance: Double
	}

	/// Returns the position of a point of the Earth, fixed in the ITRS, relative to the shadow
	/// some days after the origin.
	///
	/// - Parameters:
	///   - days: The days after the origin.
	///   - point: The point, in the ITRS, in equatorial radii of the Earth.
	func ground(_ days: Double, point: Vector3) throws(Sun.EclipseError) -> GroundSample {
		let sample = try sample(days)
		let position = try earthFrames(at: sample.instant).date(fromITRS: point)
		let (xi, eta, zeta) = (position.dot(sample.east), position.dot(sample.north), position.dot(sample.axis))
		let (dx, dy) = (sample.x - xi, sample.y - eta)
		let radius = abs(sample.l2 - zeta * sample.tanF2)
		return GroundSample(time: days, instant: sample.instant, offset: (dx, dy), umbralDistance: (dx * dx + dy * dy).squareRoot() - radius)
	}

	/// Returns where an eclipse is greatest at greatest eclipse, on the WGS84 ellipsoid.
	///
	/// For a central eclipse it is the point where the axis meets the Earth; otherwise the point
	/// of the Earth's limb nearest the axis, where the line parallel to the axis through the
	/// nearest point of the Earth's outline on the plane touches the Earth, and the Sun is on
	/// the horizon. The Sun's altitude and azimuth there are those of the axis toward the Sun,
	/// within the Sun's parallax of 9" of its own, without refraction.
	///
	/// For a central eclipse, the place is on the central line. The duration of the central
	/// phase there is from when the edge of the umbra or the antumbra reaches the place to when
	/// it leaves it, each found to 0.01 s, as the place turns with the Earth. The path's width
	/// is the width across the place of the band the umbra or the antumbra sweeps over the
	/// plane tangent to the Earth there, as eclipse catalogs give it: on the fundamental plane,
	/// the circle of the shadow's radius moving relative to the place sweeps a band twice its
	/// radius wide, which the width on the tangent plane, across the direction of the path,
	/// enlarges as it slopes away from the fundamental plane. Where the Sun is low, the Earth's
	/// surface curves away from the tangent plane under the wide path, and the distance between
	/// the path's limits along the surface is a few percent wider. Where the shadow isn't wholly
	/// on the Earth at greatest eclipse, its path has only one limit there, and no width.
	///
	/// - Parameter greatest: The sample of greatest eclipse.
	func site(_ greatest: SolarEclipseSample) throws(Sun.EclipseError) -> Sun.Eclipse.Site {
		let frames = try earthFrames(at: greatest.instant)
		let flattening = Ellipsoid.wgs84.flattening
		let polarSquared = (1 - flattening) * (1 - flattening)
		let point: Vector3
		if let zeta = greatest.zeta {
			point = greatest.x * greatest.east + greatest.y * greatest.north + zeta * greatest.axis
		} else {
			// The line parallel to the axis through the nearest point of the outline touches the
			// ellipsoid X² + Y² + Z²/(1 - f)² = 1 where its quadratic has a double root.
			let nearest = nearestPointOfEllipse(x: greatest.x, y: greatest.y, b: greatest.rho1)
			let p = nearest.x * greatest.east + nearest.y * greatest.north
			let g = greatest.axis
			let a = g.x * g.x + g.y * g.y + g.z * g.z / polarSquared
			let b = p.x * g.x + p.y * g.y + p.z * g.z / polarSquared
			point = p - (b / a) * g
		}
		let earthRadius = earthEquatorialRadius.astronomicalUnits
		let fixed = frames.itrs(fromDate: point)
		let (latitude, longitude, _) = Ellipsoid.wgs84.geodetic(fixed * earthRadius)
		let (sinLatitude, cosLatitude) = Math.sincos(latitude)
		let (sinLongitude, cosLongitude) = Math.sincos(longitude)
		let up = Vector3(cosLatitude * cosLongitude, cosLatitude * sinLongitude, sinLatitude)
		let east = Vector3(-sinLongitude, cosLongitude, 0)
		let north = Vector3(-sinLatitude * cosLongitude, -sinLatitude * sinLongitude, cosLatitude)
		let sun = frames.itrs(fromDate: greatest.axis)
		let altitude = Math.asin(max(-1, min(1, up.dot(sun))))
		var azimuth = Math.atan2(sun.dot(east), sun.dot(north))
		if azimuth < 0 {
			azimuth += twoPi
		}
		var pathWidth: Distance? = nil
		var centralPhase: ClosedRange<Instant<TT>>? = nil
		if greatest.zeta != nil {
			// The place's motion relative to the shadow on the plane, over a minute about
			// greatest eclipse
			let step = 30.0 / secondsPerDay
			let (before, after) = (try ground(greatest.time - step, point: fixed), try ground(greatest.time + step, point: fixed))
			let motion = (x: (after.offset.x - before.offset.x) / (2 * step), y: (after.offset.y - before.offset.y) / (2 * step))
			let speed = (motion.x * motion.x + motion.y * motion.y).squareRoot()
			let radius = abs(greatest.surfaceL2)
			// The path's direction on the surface: the motion on the plane lifted along the axis
			// onto the plane tangent to the Earth at the place
			let normal = frames.date(fromITRS: up)
			let velocity = motion.x * greatest.east + motion.y * greatest.north
			let rise = normal.dot(greatest.axis)
			let along = velocity - (velocity.dot(normal) / rise) * greatest.axis
			if speed > 0, along.length > 0, rise > 0 {
				// The band's area on the plane, 2r times a length of motion, is its area on the
				// tangent plane times the slope, so its width there is that area over the length.
				// A path that runs off the Earth's limb at greatest eclipse has no width across.
				if greatest.edge + abs(greatest.l2) < 0 {
					pathWidth = .kilometers(2 * radius * speed / (rise * along.length) * earthEquatorialRadius.kilometers)
				}
				let half = radius / speed
				centralPhase = try groundContact(greatest.time, point: fixed, predicted: half, before: true).instant ... groundContact(greatest.time, point: fixed, predicted: half, before: false).instant
			}
		}
		return Sun.Eclipse.Site(latitude: Angle(radians: latitude), longitude: Angle(radians: longitude), sunAltitude: Angle(radians: altitude), sunAzimuth: Angle(radians: azimuth), pathWidth: pathWidth, centralPhase: centralPhase)
	}

	/// Returns the sample at which the edge of the umbra or the antumbra reaches or leaves a
	/// point of the Earth within it at a time.
	///
	/// The shadow's radius over the point's speed predicts the instant, which a bracket from half
	/// the prediction to twice it holds, or the bracket widens until it does; ``RootFinder``
	/// finds the instant to 0.01 s.
	///
	/// - Parameters:
	///   - time: The time, at which the point is within the shadow.
	///   - point: The point, in the ITRS, in equatorial radii of the Earth.
	///   - predicted: The days from the time to the contact, about.
	///   - before: Whether the contact is before the time.
	func groundContact(_ time: Double, point: Vector3, predicted: Double, before: Bool) throws(Sun.EclipseError) -> GroundSample {
		let sign = before ? -1.0 : 1.0
		let evaluate = { (days: Double) throws(Sun.EclipseError) -> GroundSample in try ground(days, point: point) }
		var near = try evaluate(time + sign * predicted / 2)
		if near.umbralDistance >= 0 {
			near = try evaluate(time)
		}
		var span = 2 * predicted
		var far = try evaluate(time + sign * span)
		while far.umbralDistance < 0 {
			guard span < Sun.Eclipses.contactSpan else {
				throw .eclipseNotFound
			}
			near = far
			span *= 2
			far = try evaluate(time + sign * span)
		}
		let (lower, upper) = before ? (far, near) : (near, far)
		return try RootFinder.refine(lower, upper, time: \.time, tolerance: 0.01 / secondsPerDay, maximumIterations: 100, evaluate: evaluate, function: \.umbralDistance)
	}

	/// Returns the eclipse near a time, or `nil` if there is none.
	///
	/// - Parameters:
	///   - time: The time, a new Moon or near the eclipse.
	///   - isNewMoon: Whether the time is a new Moon, at which the axis is within about 0.5% of
	///     its least distance from the Earth's center, so a new Moon at which it is farther from
	///     the Earth than the penumbra's radius has no eclipse.
	func eclipse(near time: Double, isNewMoon: Bool = true) throws(Sun.EclipseError) -> Sun.Eclipse? {
		if isNewMoon {
			let new = try sample(time)
			guard 0.99 * new.edge < new.l1 else {
				return nil
			}
		}
		let (greatest, speed) = try greatest(near: time)
		// Near full Moon the axis from the Moon toward the Sun also passes near the Earth, but
		// the Moon is beyond the Earth, where it casts no shadow on it.
		guard greatest.z > 0, greatest.edge < greatest.l1 else {
			return nil
		}
		let (l1, l2) = (greatest.l1, abs(greatest.l2))
		let partialPhase = try contact(greatest, speed: speed, distance: l1, before: true) { $0.edge - $0.l1 }.instant ... contact(greatest, speed: speed, distance: l1, before: false) { $0.edge - $0.l1 }.instant
		var umbralPhase: ClosedRange<Instant<TT>>? = nil
		if greatest.edge < l2 {
			umbralPhase = try contact(greatest, speed: speed, distance: l2, before: true) { $0.edge - abs($0.l2) }.instant ... contact(greatest, speed: speed, distance: l2, before: false) { $0.edge - abs($0.l2) }.instant
		}

		let kind: Sun.Eclipse.Kind
		let magnitude: Double
		var centralPhase: ClosedRange<Instant<TT>>? = nil
		if greatest.zeta != nil {
			let first = try contact(greatest, speed: speed, distance: 0, before: true) { $0.edge }
			let last = try contact(greatest, speed: speed, distance: 0, before: false) { $0.edge }
			centralPhase = first.instant ... last.instant
			// The eclipse is total where the umbra's vertex is beyond the Earth's surface along
			// the central line, and annular where it falls short; at the ends of the line the
			// surface is on the fundamental plane.
			var isTotal: Set<Bool> = [greatest.surfaceL2 < 0, first.l2 < 0, last.l2 < 0]
			for index in 1 ..< Sun.Eclipses.centralSpans {
				let sample = try sample(first.time + (last.time - first.time) * Double(index) / Double(Sun.Eclipses.centralSpans))
				if sample.zeta != nil {
					isTotal.insert(sample.surfaceL2 < 0)
				}
			}
			kind = isTotal.count > 1 ? .hybrid : isTotal.contains(true) ? .total : .annular
			// The ratio of the Moon's apparent diameter to the Sun's on the central line
			magnitude = (greatest.surfaceL1 - greatest.surfaceL2) / (greatest.surfaceL1 + greatest.surfaceL2)
		} else {
			// The umbra or the antumbra touches the Earth's limb, on the plane, or only the
			// penumbra does.
			kind = greatest.edge >= abs(greatest.l2) ? .partial : greatest.l2 < 0 ? .total : .annular
			// The fraction of the Sun's diameter covered at the Earth's limb nearest the axis
			magnitude = (greatest.l1 - greatest.edge) / (greatest.l1 + greatest.l2)
		}
		let gamma = greatest.centerSquared.squareRoot() * (greatest.y < 0 ? -1 : 1)
		return Sun.Eclipse(kind: kind, isCentral: greatest.zeta != nil, greatestEclipse: greatest.instant, gamma: gamma, magnitude: magnitude, greatestEclipseSite: try site(greatest), partialPhase: partialPhase, umbralPhase: umbralPhase, centralPhase: centralPhase, radii: radii)
	}

	/// Returns the eclipses greatest from some days after the origin to others, in order.
	///
	/// The new Moons of the span are examined, and where the axis of the shadow is near the
	/// Earth at the span's start or end, the eclipse there, which may be greatest within the
	/// span though its new Moon is outside it. The ephemeris is evaluated outside the span only
	/// for such an eclipse, and for the contacts of an eclipse.
	func eclipses(from start: Double, to end: Double) throws(Sun.EclipseError) -> [Sun.Eclipse] {
		var times = try newMoons(from: start, to: end).map { (time: $0, isNewMoon: true) }
		if try sample(start).centerSquared < Sun.Eclipses.nearAxis * Sun.Eclipses.nearAxis {
			times.insert((start, false), at: 0)
		}
		if try sample(end).centerSquared < Sun.Eclipses.nearAxis * Sun.Eclipses.nearAxis {
			times.append((end, false))
		}
		var eclipses: [Sun.Eclipse] = []
		let (first, last) = (try instant(start), try instant(end))
		for (time, isNewMoon) in times {
			guard let eclipse = try eclipse(near: time, isNewMoon: isNewMoon), eclipse.greatestEclipse >= first, eclipse.greatestEclipse <= last else {
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

extension Sun {
	/// Returns the eclipses of the Sun by the Moon greatest in an interval, in order.
	///
	/// The Moon's and the Sun's places are their apparent places seen from the center of the
	/// Earth, from which the axis of the Moon's shadow, its cones, and the Earth's outline on the
	/// fundamental plane follow, as for the Besselian elements. Each new Moon near which the axis
	/// is close enough to the Earth is examined: the instant of greatest eclipse, when the axis
	/// is nearest the Earth's center, is found to about 0.1 s, then each contact to 0.1 s.
	///
	/// ```swift
	/// let eclipses = try Sun.eclipses(from: start, to: end)
	/// let next = try Sun.nextEclipse(after: instant)
	/// ```
	///
	/// The radii of the Moon and the Sun are an ``Sun/Eclipse/Radii``, by default NASA's, and the
	/// Earth is the WGS84 ellipsoid.
	///
	/// The eclipses from 2001 to 2100 match NASA's Five Millennium Catalog of Solar Eclipses,
	/// computed with the VSOP87 and ELP-2000/82 theories, within its rounding: every kind and
	/// whether the eclipse is central, greatest eclipse within 0.52 s, gamma and the magnitude
	/// within 0.00007, and with its ΔT, where the eclipse is greatest, the Sun's altitude, and the
	/// central duration there to the degree and the second, and the path's width within 0.7 km
	/// where the Sun is over 30° high, and within 1% where it is lower. With EclipseWise's radii
	/// and ΔT, eclipses of each kind match Espenak's EclipseWise, computed with DE405: the contacts
	/// within 0.1 s, where the eclipse is greatest within 0.05', the Sun's altitude and azimuth
	/// there within 0.05°, the path's width within 0.1 km, or within 0.6% for a Sun 12° high, and
	/// the central duration within 0.2 s. Each eclipse samples the shadow about 85 times, each
	/// placing the Sun and the Moon, so at the built-in ephemeris's full precision it takes about
	/// 0.5 s in a release build, at ``SeriesPrecision/tenthArcsecond``, which matches as closely,
	/// about 70 ms, and at ``SeriesPrecision/arcsecond``, which moves greatest eclipse by under 1
	/// s, gamma and the magnitude by under 0.00015, and where it is greatest by under 0.3', about
	/// 25 ms.
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
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The eclipses, in order of their greatest eclipse.
	/// - Throws:
	///   - ``Sun/EclipseError/invalidInterval`` if `end` is before `start`.
	///   - ``Sun/EclipseError/timescaleConversion(_:)`` if the interval can't be converted to
	///     TT.
	///   - ``Sun/EclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as outside the ephemeris's coverage.
	public static func eclipses<E: GeocentricEphemeris, Scale: Timescale>(by moon: E.Body, from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, radii: Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> [Sun.Eclipse] {
		let interval: SearchInterval
		do throws(SearchInterval.Failure) {
			interval = try SearchInterval(from: start, to: end, context: context)
		} catch {
			switch error {
			case .invalidInterval: throw .invalidInterval
			case let .timescaleConversion(error): throw .timescaleConversion(error)
			}
		}
		let search = SolarEclipseSearch(origin: interval.start.julianDate, moon: moon, earthOrientation: earthOrientation, ephemeris: ephemeris, radii: radii)
		return try search.eclipses(from: 0, to: interval.length)
	}

	/// Returns the eclipses of the Sun by the Moon greatest in an interval, in order, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - start: The start of the interval.
	///   - end: The end of the interval.
	///   - context: Observational data for converting the interval to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The eclipses, in order of their greatest eclipse.
	/// - Throws: A ``Sun/EclipseError``, as the method taking an ephemeris does.
	public static func eclipses<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full, radii: Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> [Sun.Eclipse] {
		try eclipses(by: BuiltInEphemeris.Body.moon, from: start, to: end, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), radii: radii)
	}

	/// Returns the first eclipse of the Sun by the Moon greatest after an instant.
	///
	/// The search steps from new Moon to new Moon, examining each, and stops at the eclipse. An
	/// eclipse greatest within 0.5 s of the instant, as when the instant is the greatest eclipse
	/// of one found earlier, is taken as at it, not after it.
	///
	/// - Parameters:
	///   - moon: The Moon.
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - ephemeris: The ephemeris of the Sun, the Earth, and the Moon.
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The eclipse.
	/// - Throws:
	///   - ``Sun/EclipseError/timescaleConversion(_:)`` if `instant` can't be converted to TT.
	///   - ``Sun/EclipseError/ephemeris(_:)`` if a place of the Sun or the Moon fails, as for
	///     an ``Observation``, such as for an eclipse past the ephemeris's coverage.
	///   - ``Sun/EclipseError/eclipseNotFound`` if there is no eclipse within 14 lunations, as
	///     for an ephemeris whose Moon doesn't move as the Moon does.
	public static func nextEclipse<E: GeocentricEphemeris, Scale: Timescale>(by moon: E.Body, after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, ephemeris: E, radii: Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> Sun.Eclipse {
		let start: Instant<TT>
		do throws(TimescaleConversionError) {
			start = try instant.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		let search = SolarEclipseSearch(origin: start.julianDate, moon: moon, earthOrientation: earthOrientation, ephemeris: ephemeris, radii: radii)
		/// Whether an eclipse is greatest after the instant, not within `Eclipses.sameEclipse` of
		/// it, as when the instant is an eclipse found earlier
		func isAfter(_ eclipse: Sun.Eclipse) -> Bool {
			Astrometry.days(from: Instant<TDB>(start.julianDate), to: Instant<TDB>(eclipse.greatestEclipse.julianDate)) > Eclipses.sameEclipse
		}
		// An eclipse greatest just after the instant may have its new Moon just before.
		if try search.sample(0).centerSquared < Eclipses.nearAxis * Eclipses.nearAxis, let eclipse = try search.eclipse(near: 0, isNewMoon: false), isAfter(eclipse) {
			return eclipse
		}
		var from = 0.0
		for _ in 0 ..< Eclipses.maximumLunations {
			guard let time = try search.newMoons(from: from, to: from + Moon.Phases.month, first: true).first else {
				break
			}
			if let eclipse = try search.eclipse(near: time), isAfter(eclipse) {
				return eclipse
			}
			from = time + 1
		}
		throw .eclipseNotFound
	}

	/// Returns the first eclipse of the Sun by the Moon greatest after an instant, with the
	/// built-in ephemeris.
	///
	/// - Parameters:
	///   - instant: The instant to search from.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation, whose celestial pole offsets and
	///     precision apply to the nutation.
	///   - precision: The precision of the ephemeris, by default ``SeriesPrecision/full``.
	///   - radii: The radii of the Moon and the Sun, by default NASA's.
	/// - Returns: The eclipse.
	/// - Throws: A ``Sun/EclipseError``, as the method taking an ephemeris does.
	public static func nextEclipse<Scale: Timescale>(after instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model, precision: SeriesPrecision = .full, radii: Eclipse.Radii = .nasa) throws(Sun.EclipseError) -> Sun.Eclipse {
		try nextEclipse(by: BuiltInEphemeris.Body.moon, after: instant, context: context, earthOrientation: earthOrientation, ephemeris: BuiltInEphemeris(precision: precision), radii: radii)
	}
}
