//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct PrecisionTests {
	/// Microarcseconds per radian.
	static let uas = microarcsecondsPerRadian

	/// The bound of each level, in microarcseconds.
	static func bound(_ precision: Precision) -> Double {
		switch precision {
		case .full: 0
		case .tenMilliarcseconds: 10_000
		case .tenthArcsecond: 100_000
		case .arcsecond: 1_000_000
		case .tenArcseconds: 10_000_000
		}
	}

	static func angle(_ a: Vector3, _ b: Vector3) -> Double {
		Math.atan2(a.cross(b).length, a.dot(b)) * uas
	}

	/// Returns the angle of the rotation between two rotations, the largest displacement of any
	/// direction between them, in µas.
	///
	/// For a rotation by θ, the trace is 1 + 2 cos θ, and the antisymmetric part is 2 sin θ times
	/// the axis.
	static func angle(_ a: Rotation<ICRS, ICRS>, _ b: Rotation<ICRS, ICRS>) -> Double {
		let (r0, r1, r2) = (a * b.inverse).storage
		let axis = Vector3(r2.y - r1.z, r0.z - r2.x, r1.x - r0.y)
		return Math.atan2(axis.length, r0.x + r1.y + r2.z - 1) * uas
	}

	/// Returns the unit vector of a place on the horizon.
	static func horizontal(_ place: ObservedPlace) -> Vector3 {
		let (sinAltitude, cosAltitude) = Math.sincos(place.altitude.radians)
		let (sinAzimuth, cosAzimuth) = Math.sincos(place.azimuth.radians)
		return Vector3(cosAltitude * cosAzimuth, cosAltitude * sinAzimuth, sinAltitude)
	}

	@Test func rotationAngle() {
		// A rotation about (1, 1, 1), which moves each axis by less than its angle
		let angle = Angle(arcseconds: 1.1)
		let (s, c) = Math.sincos(angle.radians / 2)
		let q = Vector3(1, 1, 1) / Vector3(1, 1, 1).length * s
		// The rotation matrix of the quaternion (c, q)
		let rotation = Rotation<ICRS, ICRS>(uncheckedRows:
			Vector3(1 - 2 * (q.y * q.y + q.z * q.z), 2 * (q.x * q.y - c * q.z), 2 * (q.x * q.z + c * q.y)),
			Vector3(2 * (q.x * q.y + c * q.z), 1 - 2 * (q.x * q.x + q.z * q.z), 2 * (q.y * q.z - c * q.x)),
			Vector3(2 * (q.x * q.z - c * q.y), 2 * (q.y * q.z + c * q.x), 1 - 2 * (q.x * q.x + q.y * q.y)))
		#expect(abs(Self.angle(rotation, .identity) - angle.radians * Self.uas) < 1e-3)
		let axes = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)].map { Self.angle(rotation.apply(to: $0), $0) }
		#expect(axes.allSatisfy { $0 < 0.9 * angle.radians * Self.uas })
	}

	/// Returns the counts of a series at each level.
	static func counts(_ counts: (Int32, Int32, Int32, Int32, Int32)) -> [Int] {
		Precision.allCases.map { Int(levelValue(counts, $0.level)) }
	}

	@Test func levelsArePrefixes() {
		// Each level keeps the leading terms of a finer one's.
		var series: [[Int]] = []
		for data in VSOP2013.seriesData {
			series += data.series.map { Self.counts($0.counts) }
		}
		let lunar = ELPMPP02.DE405.fittedSeries
		series += lunar.mainSeries.map { Self.counts($0.counts) } + lunar.perturbationSeries.map { Self.counts($0.counts) }
		for table in [IAU2006.nutationInLongitude, IAU2006.nutationInObliquity, IAU2006.sPlusHalfXY] {
			series += table.series.map { Self.counts($0.counts) }
		}
		for counts in series {
			#expect(counts == counts.sorted(by: >) && counts[0] > 0, "\(counts)")
		}
		// The coarsest levels keep far fewer terms.
		let mars = VSOP2013.Body.mars.seriesData?.series.map { Self.counts($0.counts) } ?? []
		let total = (0 ..< 5).map { level in mars.reduce(0) { $0 + $1[level] } }
		#expect(total[0] == VSOP2013.Body.mars.seriesData?.termCount)
		#expect(total[4] * 20 < total[0])
	}

	@Test func dataDescribesItsTruncation() throws {
		// The span and each level's thresholds come with the data.
		#expect(builtInEphemerisCoverage == (try JulianDate(julianEpoch: 1000)) ... (try JulianDate(julianEpoch: 3000)))
		#expect(ELPMPP02.dataSpan == 1000 ... 3000)
		for data in VSOP2013.seriesData {
			#expect(data.span == 1000 ... 3000)
			let thresholds = [data.thresholds.0, data.thresholds.1, data.thresholds.2, data.thresholds.3, data.thresholds.4]
			#expect(thresholds == thresholds.sorted() && thresholds[0] > 0)
		}
		for table in [IAU2006.nutationInLongitude, IAU2006.nutationInObliquity, IAU2006.sPlusHalfXY] {
			let thresholds = [table.thresholds.0, table.thresholds.1, table.thresholds.2, table.thresholds.3, table.thresholds.4]
			#expect(thresholds == thresholds.sorted() && thresholds[0] == 0)
		}
	}

	@Test func levelsAreWithinTheirBounds() throws {
		// The direction of each planet and the Moon from the Earth, plus the nutation, at
		// dates across the coverage
		let full = BuiltInEphemeris()
		let bodies: [BuiltInEphemeris.Body] = [.sun, .mercury, .venus, .moon, .mars, .jupiterBarycenter, .saturnBarycenter, .uranusBarycenter, .neptuneBarycenter]
		var largest: [Precision: Double] = [:]
		for epoch in stride(from: 1000.0, through: 3000, by: 97.3) {
			let tdb = Instant<TDB>(try JulianDate(julianEpoch: epoch))
			let directions = try bodies.map { try full.state(of: $0, relativeTo: .earth, at: tdb).position.vector }
			let t = (epoch - 2000) / 100
			let trueEquator = IAU2006.Orientation(at: t, poleOffsets: nil).trueEquator
			for precision in Precision.allCases.dropFirst() {
				let ephemeris = BuiltInEphemeris(precision: precision)
				var ephemerisError = 0.0
				for (body, direction) in zip(bodies, directions) {
					ephemerisError = max(ephemerisError, Self.angle(direction, try ephemeris.state(of: body, relativeTo: .earth, at: tdb).position.vector))
				}
				let nutationError = Self.angle(trueEquator, IAU2006.Orientation(at: t, poleOffsets: nil, precision: precision).trueEquator)
				largest[precision] = max(largest[precision] ?? 0, ephemerisError + nutationError)
				#expect(ephemerisError + nutationError <= Self.bound(precision), "\(precision) at J\(epoch)")
			}
		}
		// Each level uses much of its allowance.
		for precision in Precision.allCases.dropFirst() {
			#expect((largest[precision] ?? 0) > Self.bound(precision) / 10, "\(precision)")
		}
	}

	@Test func precisionReachesTheSeries() throws {
		let tdb = Instant<TDB>(try JulianDate(julianDate: 2_461_335.5))
		let tt = Instant<TT>(try JulianDate(julianDate: 2_461_335.5))
		for precision in Precision.allCases {
			#expect(BuiltInEphemeris(precision: precision).precision == precision)
			#expect(BuiltInEphemeris(lunarFit: .laserRanging, precision: precision).lunarFit == .laserRanging)
			#expect(EarthOrientation(precision: precision).precision == precision)
			let mars = try VSOP2013.Solution(precision: precision).state(of: .mars, at: tdb)
			let expected = try #require(VSOP2013.heliocentricState(of: .mars, at: tdb.julianDate, precision: precision))
			#expect(mars.position.vector == expected.position && mars.velocity.vector == expected.velocity)
			let moon = try ELPMPP02.DE405(precision: precision).state(of: .moon, at: tdb).position.vector
			#expect(moon == (try #require(ELPMPP02.DE405.eclipticState(at: tdb.julianDate, precision: precision))).position)
			let laserRanging = try ELPMPP02.LaserRanging(precision: precision).state(of: .moon, at: tdb).position.vector
			#expect(laserRanging == (try #require(ELPMPP02.LaserRanging.eclipticState(at: tdb.julianDate, precision: precision))).position)
			// The Earth orientation's precision sets the nutation of the frames of date.
			let nutation = IAU2006.nutation(at: tt, earthOrientation: EarthOrientation(precision: precision))
			let direct = IAU2006.nutation(at: tt.julianDate.julianCenturiesSinceJ2000, arguments: IAU2006.FundamentalArguments(at: tt.julianDate.julianCenturiesSinceJ2000), precision: precision)
			#expect(nutation.longitude.radians == direct.longitude && nutation.obliquity.radians == direct.obliquity)
		}
		// The defaults are full precision.
		#expect(BuiltInEphemeris().precision == .full && EarthOrientation.model.precision == .full)
		#expect(VSOP2013.solution.precision == .full && ELPMPP02.de405.precision == .full && ELPMPP02.laserRanging.precision == .full)
		// Coarser levels differ.
		#expect(try VSOP2013.Solution(precision: .arcsecond).state(of: .mars, at: tdb) != VSOP2013.solution.state(of: .mars, at: tdb))
	}

	@Test func observedPlacesAtALevel() throws {
		// A site's observed place of the Moon, with the ephemeris and the Earth orientation at
		// a level, is within the level's bound of the full place.
		let tdb = Instant<TDB>(try JulianDate(julianDate: 2_461_335.5))
		let site = try Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005), height: .meters(46))
		let fullSky = try site.observation(at: tdb)
		let full = try fullSky.observedPlace(of: fullSky.apparentPlace(of: .moon))
		for precision in Precision.allCases.dropFirst() {
			let sky = try site.observation(at: tdb, earthOrientation: EarthOrientation(precision: precision), ephemeris: BuiltInEphemeris(precision: precision))
			let place = try sky.observedPlace(of: sky.apparentPlace(of: .moon))
			#expect(Self.angle(Self.horizontal(place), Self.horizontal(full)) <= Self.bound(precision), "\(precision)")
		}
	}
}
