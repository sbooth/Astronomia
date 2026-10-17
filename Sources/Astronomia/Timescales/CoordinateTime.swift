//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// T0 = 1977-01-01T00:00:32.184 TT (JD 2443144.5003725), the epoch of the IAU linear relations
/// between TCG and TT (IAU 2000 Resolution B1.9) and between TCB and TDB (IAU 2006 Resolution B3).
///
/// It is 1977-01-01T00:00:00 TAI expressed in TT.
let coordinateTimeEpoch = JulianDate(uncheckedJulianDayNumber: 2_443_145, fractionFromNoon: -0.5 + TT.offsetFromTAI / secondsPerDay)

extension JulianDate {
	/// Returns the time elapsed since `start`, multiplied by `rate`, as a day interval.
	///
	/// The product is formed without intermediate rounding, so its error is negligible even for
	/// intervals of millions of years.
	///
	/// - Throws: ``TimescaleConversionError/dateOutOfRange`` if the interval or product cannot be
	///   represented.
	func elapsedTime(since start: JulianDate, scaledBy rate: Double) throws(TimescaleConversionError) -> DayInterval {
		do throws(DayIntervalError) {
			return try start.interval(to: self).multiplied(by: rate)
		}
		catch { throw TimescaleConversionError(error) }
	}
}
