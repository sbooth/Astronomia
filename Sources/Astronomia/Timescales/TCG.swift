//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Geocentric Coordinate Time (TCG).
///
/// TCG is the time coordinate of the Geocentric Celestial Reference System. TT is defined
/// as a linear scaling of TCG (IAU 2000 Resolution B1.9):
///
/// TT = TCG − L_G × (JD_TCG − T₀) × 86,400 s
///
/// where L_G = 6.969290134 × 10⁻¹⁰ and T₀ = JD 2443144.5003725, the instant
/// 1977-01-01T00:00:32.184 TT (00:00:00 TAI) at which TCG and TT agree.
///
/// TCG − TT is about 0.506 s at J2000.0, grows by about 22 ms per year, and is negative
/// before 1977.
public enum TCG: Timescale {
	public static let abbreviation = "TCG"

	/// L_G = 1 − d(TT)/d(TCG). A defining constant.
	public static let rate: Double = 6.969_290_134e-10

	/// L_G / (1 − L_G) = d(TCG)/d(TT) − 1, the rate of TCG relative to TT.
	static let rateRelativeToTT: Double = rate / (1 - rate)

	/// T₀ = 1977-01-01T00:00:32.184 TT (JD 2443144.5003725), when TCG = TT.
	public static let epoch = JulianDate(uncheckedJulianDayNumber: 2_443_145, fractionFromNoon: -0.5 + TT.offsetFromTAI / secondsPerDay)

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TT = TCG − L_G × (TCG − T₀)
		let correction = try scaledElapsedTime(since: epoch, until: julianDate, by: rate)
		do throws(JulianDateError) {
			return try julianDate.subtracting(correction)
		}
		catch { throw TimescaleConversionError(error) }
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TCG = TT + L_G / (1 − L_G) × (TT − T₀), the exact inverse of toTT
		let correction = try scaledElapsedTime(since: epoch, until: julianDate, by: rateRelativeToTT)
		do throws(JulianDateError) {
			return try julianDate.adding(correction)
		}
		catch { throw TimescaleConversionError(error) }
	}
}

extension TCG {
	/// Returns `(end − start) * rate` as a day interval.
	///
	/// The product is formed without intermediate rounding, so its error is negligible even
	/// for intervals of millions of years.
	static func scaledElapsedTime(since start: JulianDate, until end: JulianDate, by rate: Double) throws(TimescaleConversionError) -> DayInterval {
		do throws(DayIntervalError) {
			return try start.interval(to: end).multiplied(by: rate)
		}
		catch { throw TimescaleConversionError(error) }
	}
}
