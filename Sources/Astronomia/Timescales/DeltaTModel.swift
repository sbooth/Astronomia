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
	/// -10 + 31.4 ((y - 1825) / 100)^2 s, as published, which is about 44 s below the spline at
	/// -720, so ΔT steps there; the step is well within the uncertainty of ΔT at that date.
	/// Later, ΔT follows the parabola's trend offset to continue the spline; this is a rough guide
	/// to the future only, rising about 1.2 s per year in the 2020s while observed ΔT has been
	/// nearly constant.
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

extension DeltaTModel: DeltaTSource {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT. A model covers every date.
	public func deltaT(at tt: JulianDate) -> Double? {
		deltaT(decimalYear: tt.decimalYear)
	}
}
