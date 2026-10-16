//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A model of ΔT = TT - UT1 for dates without Earth orientation observations.
public enum DeltaTModel: Hashable, Sendable {
	/// The polynomials of Espenak & Meeus (2006), *Five Millennium Canon of Solar Eclipses*,
	/// fitted to Morrison & Stephenson (2004) before 2005 and extrapolated after.
	///
	/// The uncertainty grows from under a second in the 20th century to hours in antiquity.
	/// The extrapolation after 2005 has not followed Earth's rotation: by 2026 it is about
	/// 6 s larger than the observed ΔT. Use ``EarthOrientationTable`` for dates with
	/// observations.
	///
	/// The lunar secular acceleration correction for the ELP-2000/82 ephemeris, which the
	/// Canon applies before 1955 and after 2005, is not included.
	///
	/// - SeeAlso: [Polynomial Expressions for Delta T](https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
	case espenakMeeus2006

	/// The cubic spline of Stephenson, Morrison & Hohenkerk (2016), fitted to observations of
	/// eclipses and occultations from 720 BC to 2015, as revised by Morrison, Stephenson,
	/// Hohenkerk & Zawilski (2021) with further medieval observations.
	///
	/// The spline covers -720 to 2019. Earlier, ΔT follows their long-term parabola,
	/// -10 + 31.4 ((y - 1825) / 100)² s. Later, ΔT follows the parabola's trend offset to
	/// continue the spline; this is a rough guide to the future only, rising about 1.2 s per
	/// year in the 2020s while observed ΔT has been nearly constant.
	///
	/// This reconstruction uses more and re-analysed historical observations than the
	/// Morrison & Stephenson (2004) data behind ``espenakMeeus2006``, and a tidal acceleration
	/// of the Moon consistent with modern ephemerides. The two differ by up to about 4.5
	/// minutes between 700 BC and AD 1500.
	///
	/// - SeeAlso: [Stephenson, Morrison & Hohenkerk (2016)](https://doi.org/10.1098/rspa.2016.0404)
	/// - SeeAlso: [Morrison et al. (2021)](https://doi.org/10.1098/rspa.2020.0776)
	case stephensonMorrisonHohenkerk2016

	/// Returns ΔT, in seconds, for the specified decimal year.
	///
	/// - Parameter decimalYear: The decimal year in the Julian-Gregorian calendar.
	/// - Returns: ΔT = TT - UT1, in seconds.
	public func deltaT(decimalYear: Double) -> Double {
		switch self {
		case .espenakMeeus2006:
			Self.espenakMeeus2006(decimalYear)
		case .stephensonMorrisonHohenkerk2016:
			Self.stephensonMorrisonHohenkerk2016(decimalYear)
		}
	}
}

extension DeltaTModel {
	/// ΔT from the Espenak & Meeus (2006) polynomials.
	///
	/// - Parameter y: The decimal year.
	static func espenakMeeus2006(_ y: Double) -> Double {
		/// The long-term parabola of Morrison & Stephenson (2004).
		func parabola(_ y: Double) -> Double {
			let u = (y - 1820) / 100
			return -20 + 32 * u * u
		}

		switch y {
		case ..<(-500):
			return parabola(y)
		case ..<500:
			let u = y / 100
			return 10583.6 + u * (-1014.41 + u * (33.78311 + u * (-5.952053 + u * (-0.1798452 + u * (0.022174192 + u * 0.0090316521)))))
		case ..<1600:
			let u = (y - 1000) / 100
			return 1574.2 + u * (-556.01 + u * (71.23472 + u * (0.319781 + u * (-0.8503463 + u * (-0.005050998 + u * 0.0083572073)))))
		case ..<1700:
			let t = y - 1600
			return 120 + t * (-0.9808 + t * (-0.01532 + t / 7129))
		case ..<1800:
			let t = y - 1700
			return 8.83 + t * (0.1603 + t * (-0.0059285 + t * (0.00013336 - t / 1_174_000)))
		case ..<1860:
			let t = y - 1800
			return 13.72 + t * (-0.332447 + t * (0.0068612 + t * (0.0041116 + t * (-0.00037436 + t * (0.0000121272 + t * (-0.0000001699 + t * 0.000000000875))))))
		case ..<1900:
			let t = y - 1860
			return 7.62 + t * (0.5737 + t * (-0.251754 + t * (0.01680668 + t * (-0.0004473624 + t / 233_174))))
		case ..<1920:
			let t = y - 1900
			return -2.79 + t * (1.494119 + t * (-0.0598939 + t * (0.0061966 - t * 0.000197)))
		case ..<1941:
			let t = y - 1920
			return 21.20 + t * (0.84493 + t * (-0.076100 + t * 0.0020936))
		case ..<1961:
			let t = y - 1950
			return 29.07 + t * (0.407 + t * (-1.0 / 233 + t / 2547))
		case ..<1986:
			let t = y - 1975
			return 45.45 + t * (1.067 + t * (-1.0 / 260 - t / 718))
		case ..<2005:
			let t = y - 2000
			return 63.86 + t * (0.3345 + t * (-0.060374 + t * (0.0017275 + t * (0.000651814 + t * 0.00002373599))))
		case ..<2050:
			let t = y - 2000
			return 62.92 + t * (0.32217 + t * 0.005589)
		case ..<2150:
			return parabola(y) - 0.5628 * (2150 - y)
		default:
			return parabola(y)
		}
	}
}

extension DeltaTModel: DeltaTSource {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT. A model covers every date.
	public func deltaT(at tt: JulianDate) -> Double? {
		deltaT(decimalYear: tt.decimalYear)
	}
}
