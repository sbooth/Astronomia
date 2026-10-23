//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaData

/// The planetary solution VSOP2013 (Simon et al. 2013), fitted to the INPOP10a ephemeris.
///
/// The solution gives heliocentric elliptic elements of the planets and the Earth-Moon
/// barycenter as series in TDB, in its own realization of the dynamical ecliptic and equinox
/// of J2000.0, ``Ecliptic``. ``Solution`` gives their states. The built-in series are
/// truncated for J1000.0 to J3000.0 so that the geocentric error from truncation is near
/// 0.5 mas, or below the solution's own error, and coarser ``Precision`` levels sum fewer of
/// their terms.
///
/// - Note: Simon, J.-L., Francou, G., Fienga, A., Manche, H. (2013). New analytical planetary
///   theories VSOP2013 and TOP2013. Astronomy & Astrophysics 557, A49.
public enum VSOP2013 {
	/// A body of the solution.
	///
	/// The solution gives the outer planets as the barycenters of their systems, which differ
	/// from the planets by up to a few hundred kilometers. The solar system barycenter is the
	/// center of mass of the Sun and the solution's bodies, with their masses from INPOP10a.
	public enum Body: Hashable, Sendable, CaseIterable {
		/// The barycenter of the solar system.
		case solarSystemBarycenter
		/// The Sun.
		case sun
		/// Mercury.
		case mercury
		/// Venus.
		case venus
		/// The barycenter of the Earth and the Moon.
		case earthMoonBarycenter
		/// Mars.
		case mars
		/// The barycenter of Jupiter and its satellites.
		case jupiterBarycenter
		/// The barycenter of Saturn and its satellites.
		case saturnBarycenter
		/// The barycenter of Uranus and its satellites.
		case uranusBarycenter
		/// The barycenter of Neptune and its satellites.
		case neptuneBarycenter
		/// The barycenter of Pluto and its satellites.
		case plutoBarycenter
	}

	/// The dynamical ecliptic and equinox of J2000.0 as realized by VSOP2013.
	///
	/// The frame is the ICRS rotated by R1(ε) R3(φ), with ε = 23° 26' 21.41136" and
	/// φ = -0.05188" from the solution's documentation.
	///
	/// - Note: This is not ``EclipticJ2000``, the ecliptic of the IAU 2006 precession, from
	///   which it differs by a few milliarcseconds.
	public enum Ecliptic: EclipticFrame, FixedReferenceFrame {
		public static let name = "VSOP2013 ecliptic J2000"

		public static let rotationFromICRS = rotationToICRS.inverse

		/// The rotation to the ICRS, R3(-φ) R1(-ε).
		static let rotationToICRS = Rotation<Ecliptic, ICRS>.aboutZ(.arcseconds(0.051_88))
			* Rotation<Ecliptic, Ecliptic>.aboutX(.arcseconds(-84_381.411_36))
	}

	/// The gravitational parameter of the Sun, in au³/day², from INPOP10a as given in
	/// VSOP2013.f.
	static let sunGravitationalParameter = 2.959_122_083_684_143_826_9e-4
}

/// The TDB dates of the built-in series of VSOP2013 and ELP/MPP02, the span common to every
/// series as the data gives it: J1000.0 to J3000.0.
let builtInEphemerisCoverage: ClosedRange<JulianDate> = {
	let spans = VSOP2013.seriesData.map(\.span) + [ELPMPP02.dataSpan]
	let start = spans.map(\.lowerBound).max() ?? 2000
	let end = spans.map(\.upperBound).min() ?? 2000
	do throws(JulianDateError) {
		return try JulianDate(julianEpoch: start) ... JulianDate(julianEpoch: end)
	} catch {
		preconditionFailure("The built-in series' span J\(start) to J\(end) is not representable")
	}
}()

/// The TDB instants of the built-in series, J1000.0 to J3000.0.
let builtInEphemerisInstants = Instant<TDB>(builtInEphemerisCoverage.lowerBound) ... Instant(builtInEphemerisCoverage.upperBound)

extension VSOP2013 {
	/// The series of each body, in the order of the data.
	static let seriesData = [
		SeriesData(astronomia_vsop2013_mercury),
		SeriesData(astronomia_vsop2013_venus),
		SeriesData(astronomia_vsop2013_earth_moon_barycenter),
		SeriesData(astronomia_vsop2013_mars),
		SeriesData(astronomia_vsop2013_jupiter),
		SeriesData(astronomia_vsop2013_saturn),
		SeriesData(astronomia_vsop2013_uranus),
		SeriesData(astronomia_vsop2013_neptune),
		SeriesData(astronomia_vsop2013_pluto),
	]
}

extension VSOP2013.Body {
	/// The body's series, or `nil` for the Sun and the solar system barycenter, which have
	/// none.
	var seriesData: VSOP2013.SeriesData? {
		switch self {
		case .solarSystemBarycenter, .sun: nil
		case .mercury: VSOP2013.seriesData[0]
		case .venus: VSOP2013.seriesData[1]
		case .earthMoonBarycenter: VSOP2013.seriesData[2]
		case .mars: VSOP2013.seriesData[3]
		case .jupiterBarycenter: VSOP2013.seriesData[4]
		case .saturnBarycenter: VSOP2013.seriesData[5]
		case .uranusBarycenter: VSOP2013.seriesData[6]
		case .neptuneBarycenter: VSOP2013.seriesData[7]
		case .plutoBarycenter: VSOP2013.seriesData[8]
		}
	}

	/// The mean motion in longitude, in radians per thousand Julian years, from VSOP2013.f, or
	/// `nil` for the Sun and the solar system barycenter.
	///
	/// The series of the mean longitude leave out this term, which is added separately.
	var meanMotion: Double? {
		switch self {
		case .solarSystemBarycenter, .sun: nil
		case .mercury: 0.260_879_031_406_855_5e5
		case .venus: 0.102_132_855_474_344_5e5
		case .earthMoonBarycenter: 0.628_307_585_035_321_5e4
		case .mars: 0.334_061_243_414_545_7e4
		case .jupiterBarycenter: 0.529_690_961_562_325_0e3
		case .saturnBarycenter: 0.213_299_086_108_488_0e3
		case .uranusBarycenter: 0.747_816_590_307_780_0e2
		case .neptuneBarycenter: 0.381_329_722_261_250_0e2
		case .plutoBarycenter: 0.253_356_602_043_700_0e2
		}
	}

	/// The gravitational parameter of the body, with its satellites, in au³/day², from
	/// INPOP10a as given in VSOP2013.f, or `nil` for the solar system barycenter.
	var gravitationalParameter: Double? {
		switch self {
		case .solarSystemBarycenter: nil
		case .sun: VSOP2013.sunGravitationalParameter
		case .mercury: 4.912_547_451_450_811_869_9e-11
		case .venus: 7.243_452_486_162_702_700_0e-10
		case .earthMoonBarycenter: 8.997_011_603_631_609_118_2e-10
		case .mars: 9.549_535_105_779_258_059_8e-11
		case .jupiterBarycenter: 2.825_345_842_083_778_000_0e-7
		case .saturnBarycenter: 8.459_715_185_680_658_739_8e-8
		case .uranusBarycenter: 1.292_024_916_781_969_390_0e-8
		case .neptuneBarycenter: 1.524_358_900_784_276_280_0e-8
		case .plutoBarycenter: 2.188_699_765_425_969_680_0e-12
		}
	}
}

extension VSOP2013 {
	/// Returns the elliptic elements of a body at a time.
	///
	/// - Parameters:
	///   - body: A body with series.
	///   - t: TDB in thousands of Julian years from J2000.0.
	///   - precision: The precision level.
	/// - Returns: The elements, with the mean longitude in the right-open interval [0, 2π).
	static func elements(of body: Body, at t: Double, precision: Precision = .full) -> EllipticElements {
		guard let seriesData = body.seriesData, let meanMotion = body.meanMotion else {
			preconditionFailure("\(body) has no series")
		}
		let sums = seriesData.evaluate(at: t, variables: 6, precision: precision)
		var meanLongitude = (sums[1] + meanMotion * t).truncatingRemainder(dividingBy: twoPi)
		if meanLongitude < 0 {
			meanLongitude += twoPi
		}
		return EllipticElements(a: sums[0], meanLongitude: meanLongitude, k: sums[2], h: sums[3], q: sums[4], p: sums[5])
	}

	/// Returns the state of a body with series on its heliocentric orbit.
	///
	/// - Parameters:
	///   - body: A body with series.
	///   - t: TDB in thousands of Julian years from J2000.0.
	///   - precision: The precision level.
	private static func orbitalState(of body: Body, at t: Double, precision: Precision) -> (position: Vector3, velocity: Vector3) {
		guard let gm = body.gravitationalParameter else { preconditionFailure("\(body) has no series") }
		return elements(of: body, at: t, precision: precision).state(gm: sunGravitationalParameter + gm)
	}

	/// Returns a body's heliocentric position and velocity in the solution's ecliptic.
	///
	/// - Parameters:
	///   - body: The body.
	///   - tdb: A Julian Date in TDB.
	///   - precision: The precision level.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	static func heliocentricState(of body: Body, at tdb: JulianDate, precision: Precision = .full) -> (position: Vector3, velocity: Vector3)? {
		guard builtInEphemerisCoverage.contains(tdb) else { return nil }
		switch body {
		case .sun:
			return (.zero, .zero)
		case .solarSystemBarycenter:
			return barycenter(at: tdb.daysSinceJ2000 / daysPerJulianMillennium, precision: precision)
		default:
			return orbitalState(of: body, at: tdb.daysSinceJ2000 / daysPerJulianMillennium, precision: precision)
		}
	}

	/// Returns the heliocentric position and velocity of the solar system barycenter, the
	/// center of mass of the Sun and the bodies of the solution, in the solution's ecliptic.
	///
	/// - Parameters:
	///   - t: TDB in thousands of Julian years from J2000.0.
	///   - precision: The precision level.
	private static func barycenter(at t: Double, precision: Precision) -> (position: Vector3, velocity: Vector3) {
		var position = Vector3.zero
		var velocity = Vector3.zero
		var total = sunGravitationalParameter
		for body in Body.allCases where body.seriesData != nil {
			guard let gm = body.gravitationalParameter else { preconditionFailure("\(body) has no mass") }
			let state = orbitalState(of: body, at: t, precision: precision)
			position = position + state.position * gm
			velocity = velocity + state.velocity * gm
			total += gm
		}
		return (position / total, velocity / total)
	}
}
