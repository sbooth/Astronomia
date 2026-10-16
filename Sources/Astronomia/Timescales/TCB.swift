//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Barycentric Coordinate Time (TCB).
///
/// TCB is the time coordinate of the Barycentric Celestial Reference System. TDB is defined
/// as a linear transformation of TCB (IAU 2006 Resolution B3):
///
/// TDB = TCB - L_B × (JD_TCB - T0) × 86,400 s + TDB0
///
/// where L_B = 1.550519768 × 10^-8, TDB0 = -6.55 × 10^-5 s, and T0 = JD 2443144.5003725.
///
/// TCB - TDB is about 11.25 s at J2000.0 and grows by about 0.489 s per year. Converting
/// to TT goes through ``TDB``, so TCB takes TDB's context and shares its accuracy.
public enum TCB: Timescale {
	public static let abbreviation = "TCB"
	public typealias Context = TDB.Context
	public static let defaultContext = TDB.defaultContext

	/// L_B = 1 - d(TDB)/d(TCB). A defining constant.
	public static let rate: Double = 1.550_519_768e-8

	/// L_B / (1 - L_B) = d(TCB)/d(TDB) - 1, the rate of TCB relative to TDB.
	static let rateRelativeToTDB: Double = rate / (1 - rate)

	/// TDB0, in seconds. A defining constant.
	public static let tdb0: Double = -6.55e-5

	/// T0 = JD 2443144.5003725, the same Julian Date as ``TCG/epoch``.
	public static let epoch = coordinateTimeEpoch

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		try TDB.toTT(toTDB(julianDate), context: context)
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		try fromTDB(TDB.fromTT(julianDate, context: context))
	}

	/// Converts a Julian Date from TCB to TDB.
	///
	/// - Parameter tcb: A Julian Date in TCB.
	/// - Returns: The same instant as a Julian Date in TDB.
	/// - Throws: ``TimescaleConversionError/dateOutOfRange`` if the result cannot be
	///   represented.
	public static func toTDB(_ tcb: JulianDate) throws(TimescaleConversionError) -> JulianDate {
		// TDB = TCB - L_B × (TCB - T0) + TDB0
		let correction = try tcb.elapsedTime(since: epoch, scaledBy: rate)
		do throws(JulianDateError) {
			return try tcb.subtracting(correction).adding(seconds: tdb0)
		}
		catch { throw TimescaleConversionError(error) }
	}

	/// Converts a Julian Date from TDB to TCB.
	///
	/// - Parameter tdb: A Julian Date in TDB.
	/// - Returns: The same instant as a Julian Date in TCB.
	/// - Throws: ``TimescaleConversionError/dateOutOfRange`` if the result cannot be
	///   represented.
	public static func fromTDB(_ tdb: JulianDate) throws(TimescaleConversionError) -> JulianDate {
		// TCB = (TDB - TDB0) + L_B / (1 - L_B) × ((TDB - TDB0) - T0), the exact inverse of toTDB
		let date: JulianDate
		do throws(JulianDateError) {
			date = try tdb.adding(seconds: -tdb0)
		}
		catch { throw TimescaleConversionError(error) }

		let correction = try date.elapsedTime(since: epoch, scaledBy: rateRelativeToTDB)
		do throws(JulianDateError) {
			return try date.adding(correction)
		}
		catch { throw TimescaleConversionError(error) }
	}
}
