//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import AstronomiaData

/// The planetary solution VSOP2013 (Simon et al. 2013), fitted to the INPOP10a ephemeris.
///
/// The solution gives heliocentric elliptic elements of the planets and the Earth-Moon
/// barycenter as series in TDB, in its own realization of the dynamical ecliptic and equinox
/// of J2000.0, ``Ecliptic``. ``Ephemeris`` gives their states. The built-in series are
/// truncated for J1000.0 to J3000.0 so that the geocentric error from truncation is near
/// 0.5 mas, or below the solution's own error.
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
	/// The frame is the ICRS rotated by R1(ε) R3(φ), with ε = 23° 26′ 21.41136″ and
	/// φ = -0.05188″ from the solution's documentation.
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

/// The TDB dates of the built-in series of VSOP2013 and ELP/MPP02, J1000.0 to J3000.0.
let builtInEphemerisCoverage = JulianDate(uncheckedJulianDayNumber: 2_086_295, fractionFromNoon: 0) ... JulianDate(uncheckedJulianDayNumber: 2_816_795, fractionFromNoon: 0)

/// The TDB instants of the built-in series, J1000.0 to J3000.0.
let builtInEphemerisInstants = Instant<TDB>(builtInEphemerisCoverage.lowerBound) ... Instant(builtInEphemerisCoverage.upperBound)

extension VSOP2013 {
	/// The series and constants of a body with series in the solution.
	struct Series {
		/// The position of the body's series in the data.
		let index: Int
		/// The mean motion in longitude, in radians per thousand Julian years, from VSOP2013.f.
		///
		/// The series of the mean longitude leave out this term, which is added separately.
		let meanMotion: Double
		/// The gravitational parameter of the body, with its satellites, in au³/day², from
		/// INPOP10a as given in VSOP2013.f.
		let bodyGravitationalParameter: Double

		/// The body's series.
		var terms: VSOPSeries {
			Self.all[index]
		}

		/// The gravitational parameter of the Sun and the body, in au³/day².
		var gravitationalParameter: Double {
			VSOP2013.sunGravitationalParameter + bodyGravitationalParameter
		}

		/// The series of each body, in the order of the data.
		private static let all = [
			VSOPSeries(astronomia_vsop2013_mercury),
			VSOPSeries(astronomia_vsop2013_venus),
			VSOPSeries(astronomia_vsop2013_earth_moon_barycenter),
			VSOPSeries(astronomia_vsop2013_mars),
			VSOPSeries(astronomia_vsop2013_jupiter),
			VSOPSeries(astronomia_vsop2013_saturn),
			VSOPSeries(astronomia_vsop2013_uranus),
			VSOPSeries(astronomia_vsop2013_neptune),
			VSOPSeries(astronomia_vsop2013_pluto),
		]
	}
}

extension VSOP2013.Body {
	/// The body's series and constants, or `nil` for the Sun and the solar system barycenter,
	/// which have none.
	var series: VSOP2013.Series? {
		switch self {
		case .solarSystemBarycenter, .sun: nil
		case .mercury: .init(index: 0, meanMotion: 0.260_879_031_406_855_5e5, bodyGravitationalParameter: 4.912_547_451_450_811_869_9e-11)
		case .venus: .init(index: 1, meanMotion: 0.102_132_855_474_344_5e5, bodyGravitationalParameter: 7.243_452_486_162_702_700_0e-10)
		case .earthMoonBarycenter: .init(index: 2, meanMotion: 0.628_307_585_035_321_5e4, bodyGravitationalParameter: 8.997_011_603_631_609_118_2e-10)
		case .mars: .init(index: 3, meanMotion: 0.334_061_243_414_545_7e4, bodyGravitationalParameter: 9.549_535_105_779_258_059_8e-11)
		case .jupiterBarycenter: .init(index: 4, meanMotion: 0.529_690_961_562_325_0e3, bodyGravitationalParameter: 2.825_345_842_083_778_000_0e-7)
		case .saturnBarycenter: .init(index: 5, meanMotion: 0.213_299_086_108_488_0e3, bodyGravitationalParameter: 8.459_715_185_680_658_739_8e-8)
		case .uranusBarycenter: .init(index: 6, meanMotion: 0.747_816_590_307_780_0e2, bodyGravitationalParameter: 1.292_024_916_781_969_390_0e-8)
		case .neptuneBarycenter: .init(index: 7, meanMotion: 0.381_329_722_261_250_0e2, bodyGravitationalParameter: 1.524_358_900_784_276_280_0e-8)
		case .plutoBarycenter: .init(index: 8, meanMotion: 0.253_356_602_043_700_0e2, bodyGravitationalParameter: 2.188_699_765_425_969_680_0e-12)
		}
	}
}

extension VSOP2013 {
	/// Returns the elliptic elements of a body's series at a time.
	///
	/// - Parameters:
	///   - series: The body's series.
	///   - t: TDB in thousands of Julian years from J2000.0.
	/// - Returns: The elements, with the mean longitude in the right-open interval [0, 2π).
	static func elements(of series: Series, at t: Double) -> EllipticElements {
		let sums = series.terms.evaluate(at: t, variables: 6)
		let twoPi = 2 * Double.pi
		var meanLongitude = (sums[1] + series.meanMotion * t).truncatingRemainder(dividingBy: twoPi)
		if meanLongitude < 0 {
			meanLongitude += twoPi
		}
		return EllipticElements(a: sums[0], meanLongitude: meanLongitude, k: sums[2], h: sums[3], q: sums[4], p: sums[5])
	}

	/// Returns a body's heliocentric position and velocity in the solution's ecliptic.
	///
	/// - Parameters:
	///   - body: The body.
	///   - tdb: A Julian Date in TDB.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside the coverage.
	static func heliocentricState(of body: Body, at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		guard builtInEphemerisCoverage.contains(tdb) else { return nil }
		switch body {
		case .sun:
			return (.zero, .zero)
		case .solarSystemBarycenter:
			return barycenter(at: tdb.daysSinceJ2000 / daysPerJulianMillennium)
		default:
			guard let series = body.series else { preconditionFailure("\(body) has no series") }
			return elements(of: series, at: tdb.daysSinceJ2000 / daysPerJulianMillennium).state(gm: series.gravitationalParameter)
		}
	}

	/// Returns the heliocentric position and velocity of the solar system barycenter, the
	/// center of mass of the Sun and the bodies of the solution, in the solution's ecliptic.
	///
	/// - Parameter t: TDB in thousands of Julian years from J2000.0.
	private static func barycenter(at t: Double) -> (position: Vector3, velocity: Vector3) {
		var position = Vector3.zero
		var velocity = Vector3.zero
		var total = sunGravitationalParameter
		for series in Body.allCases.compactMap(\.series) {
			let state = elements(of: series, at: t).state(gm: series.gravitationalParameter)
			position = position + state.position * series.bodyGravitationalParameter
			velocity = velocity + state.velocity * series.bodyGravitationalParameter
			total += series.bodyGravitationalParameter
		}
		return (position / total, velocity / total)
	}
}
