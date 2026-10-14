//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// International Atomic Time (TAI).
///
/// TAI = TT - 32.184 s.
///
/// - Note: TAI was defined in 1958 and took its current form in 1972. For earlier dates the
///   conversion is arithmetic only.
public enum TAI: Timescale {
	public static let abbreviation = "TAI"

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		do throws(JulianDateError) {
			return try julianDate.adding(TT.intervalFromTAI)
		}
		catch { throw TimescaleConversionError(error) }
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		do throws(JulianDateError) {
			return try julianDate.subtracting(TT.intervalFromTAI)
		}
		catch { throw TimescaleConversionError(error) }
	}
}
