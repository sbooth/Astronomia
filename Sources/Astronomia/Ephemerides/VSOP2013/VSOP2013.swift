//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import AstronomiaData

/// The VSOP2013 planetary solution (Simon et al. 2013), fitted to the INPOP10a ephemeris.
///
/// The solution gives heliocentric elliptic elements of the planets and the Earth-Moon
/// barycenter as series in TDB, in the dynamical ecliptic and equinox of J2000.0. The built-in
/// series are truncated for J1000.0 to J3000.0 so that the geocentric error from truncation is
/// near 0.5 mas, or below the solution's own error.
///
/// - Note: Simon, J.-L., Francou, G., Fienga, A., Manche, H. (2013). New analytical planetary
///   theories VSOP2013 and TOP2013. Astronomy & Astrophysics 557, A49.
enum VSOP2013 {
	/// A body of the solution.
	enum Body: Int, CaseIterable, Sendable {
		case mercury
		case venus
		case earthMoonBarycenter
		case mars
		case jupiter
		case saturn
		case uranus
		case neptune
		case pluto
	}

	/// The dynamical ecliptic and equinox of J2000.0 as realized by VSOP2013.
	enum Ecliptic: EclipticFrame, FixedReferenceFrame {
		static let name = "VSOP2013 ecliptic J2000"

		static let rotationFromICRS = rotationToICRS.inverse
	}

	/// The rotation from the solution's ecliptic to the ICRS, R3(-φ) R1(-ε), with
	/// ε = 23° 26′ 21.41136″ and φ = -0.05188″ from the solution's documentation.
	static let rotationToICRS = Rotation<Ecliptic, ICRS>.aboutZ(.arcseconds(0.051_88))
		* Rotation<Ecliptic, Ecliptic>.aboutX(.arcseconds(-84_381.411_36))

	/// The TDB dates of the built-in series, J1000.0 to J3000.0.
	static let coverage = JulianDate(uncheckedJulianDayNumber: 2_086_295, fractionFromNoon: 0)
		... JulianDate(uncheckedJulianDayNumber: 2_816_795, fractionFromNoon: 0)

	/// Julian days per thousand Julian years, the unit of time of the series.
	static let daysPerMillennium: Double = 365_250
}

extension VSOP2013.Body {
	/// The body's series.
	var series: VSOPSeries {
		Self.allSeries[rawValue]
	}

	/// The series of each body, in the order of the cases.
	private static let allSeries = [
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

	/// The mean motion in longitude, in radians per thousand Julian years, from VSOP2013.f.
	///
	/// The series of the mean longitude leave out this term, which is added separately.
	var meanMotion: Double {
		switch self {
		case .mercury: 0.260_879_031_406_855_5e5
		case .venus: 0.102_132_855_474_344_5e5
		case .earthMoonBarycenter: 0.628_307_585_035_321_5e4
		case .mars: 0.334_061_243_414_545_7e4
		case .jupiter: 0.529_690_961_562_325_0e3
		case .saturn: 0.213_299_086_108_488_0e3
		case .uranus: 0.747_816_590_307_780_0e2
		case .neptune: 0.381_329_722_261_250_0e2
		case .pluto: 0.253_356_602_043_700_0e2
		}
	}

	/// The gravitational parameter of the Sun and the body, in au³/day², from INPOP10a as
	/// given in VSOP2013.f.
	var gravitationalParameter: Double {
		let sun = 2.959_122_083_684_143_826_9e-4
		switch self {
		case .mercury: return sun + 4.912_547_451_450_811_869_9e-11
		case .venus: return sun + 7.243_452_486_162_702_700_0e-10
		case .earthMoonBarycenter: return sun + 8.997_011_603_631_609_118_2e-10
		case .mars: return sun + 9.549_535_105_779_258_059_8e-11
		case .jupiter: return sun + 2.825_345_842_083_778_000_0e-7
		case .saturn: return sun + 8.459_715_185_680_658_739_8e-8
		case .uranus: return sun + 1.292_024_916_781_969_390_0e-8
		case .neptune: return sun + 1.524_358_900_784_276_280_0e-8
		case .pluto: return sun + 2.188_699_765_425_969_680_0e-12
		}
	}
}

extension VSOP2013 {
	/// Returns a body's elliptic elements at a time.
	///
	/// - Parameters:
	///   - body: The body.
	///   - t: TDB in thousands of Julian years from J2000.0.
	/// - Returns: The elements, with the mean longitude in the right-open interval [0, 2π).
	static func elements(of body: Body, at t: Double) -> EllipticElements {
		let sums = body.series.evaluate(at: t, variables: 6)
		let twoPi = 2 * Double.pi
		var meanLongitude = (sums[1] + body.meanMotion * t).truncatingRemainder(dividingBy: twoPi)
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
	///   day, or `nil` if `tdb` is outside ``coverage``.
	static func eclipticState(of body: Body, at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		guard coverage.contains(tdb) else { return nil }
		let t = tdb.daysSinceJ2000 / daysPerMillennium
		return elements(of: body, at: t).state(gm: body.gravitationalParameter)
	}

	/// Returns a body's heliocentric position and velocity in the ICRS.
	///
	/// - Parameters:
	///   - body: The body.
	///   - tdb: A Julian Date in TDB.
	/// - Returns: The position, in astronomical units, and velocity, in astronomical units per
	///   day, or `nil` if `tdb` is outside ``coverage``.
	static func state(of body: Body, at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		guard let ecliptic = eclipticState(of: body, at: tdb) else { return nil }
		return (rotationToICRS.apply(to: ecliptic.position), rotationToICRS.apply(to: ecliptic.velocity))
	}
}
