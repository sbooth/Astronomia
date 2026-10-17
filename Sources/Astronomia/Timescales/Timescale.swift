//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A timescale in which a ``JulianDate`` can be expressed.
///
/// Conforming types are caseless enums used only as type-level tags for ``Instant``.
///
/// Every timescale converts to and from Terrestrial Time (``TT``), which acts as the hub of
/// the conversion graph. Converting between two timescales goes through TT, so each
/// timescale only needs to know its own relationship to TT (usually by way of a neighbor such
/// as ``TAI``):
///
/// ```
///             GST, QZSST, IRNWT
///                       │ 19 s
/// UTC ──leap seconds── TAI ──19 s── GPS
///  │                    ├──33 s── BDT
/// 3 h               32.184 s
///  │                    │
/// GLONASS               │
///         TCG ──L_G──  TT  ──series── TDB ──L_B── TCB
///                       │ ΔT
///                      UT1
/// ```
///
/// TT is the hub because it is the timescale of most astronomical models: TDB is a periodic
/// series in TT, and ΔT is defined as TT - UT1.
///
/// Timescales without leap seconds or a variable day length conform to
/// ``UniformTimescale``, which adds elapsed-time arithmetic to ``Instant``.
public protocol Timescale: Sendable {
	associatedtype Context: Sendable = Void
	static var defaultContext: Context { get }

	/// The conventional abbreviation of the timescale, such as `"TT"`.
	static var abbreviation: String { get }

	/// Converts a Julian Date in this timescale to TT.
	///
	/// - Parameters:
	///   - julianDate: A Julian Date in this timescale.
	///   - context: Data used by conversions that depend on observations, such as leap
	///     second tables or Earth orientation data.
	/// - Returns: The same instant as a Julian Date in TT.
	/// - Throws: A ``TimescaleConversionError`` if the conversion fails.
	static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate

	/// Converts a Julian Date from TT to this timescale.
	///
	/// - Parameters:
	///   - julianDate: A Julian Date in TT.
	///   - context: The data used by conversions that depend on observations, such as leap
	///     seconds.
	/// - Returns: The same instant as a Julian Date in this timescale.
	/// - Throws: A ``TimescaleConversionError`` if the conversion fails.
	static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate
}

extension Timescale where Context == Void {
	public static var defaultContext: Void { () }

	/// Converts a Julian Date in this timescale to TT.
	///
	/// - Parameters:
	///   - julianDate: A Julian Date in this timescale.
	/// - Returns: The same instant as a Julian Date in TT.
	/// - Throws: A ``TimescaleConversionError`` if the conversion fails.
	public static func toTT(_ julianDate: JulianDate) throws(TimescaleConversionError) -> JulianDate {
		try toTT(julianDate, context: ())
	}

	/// Converts a Julian Date from TT to this timescale.
	///
	/// - Parameters:
	///   - julianDate: A Julian Date in TT.
	/// - Returns: The same instant as a Julian Date in this timescale.
	/// - Throws: A ``TimescaleConversionError`` if the conversion fails.
	public static func fromTT(_ julianDate: JulianDate) throws(TimescaleConversionError) -> JulianDate {
		try fromTT(julianDate, context: ())
	}
}
