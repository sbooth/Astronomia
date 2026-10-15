//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Universal Time (UT1).
///
/// UT1 is the angle of Earth's rotation expressed as a time. It is not defined by a formula:
/// it follows Earth's irregular rotation and is determined by observation. It relates to TT
/// through ΔT = TT - UT1, about 69 s in 2026 and growing irregularly.
///
/// ΔT comes from the first of the context's sources that covers the date: its
/// ``EarthOrientationTable``, then its ``DeltaTTable``, then its ``DeltaTModel``. Sources can
/// differ where one hands over to the next, by up to several seconds between the model and
/// the tables, so conversions are not continuous there.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No Earth orientation data; ΔT from ``DeltaTTable/historic`` from 1657.0 to 1984.5 and
	/// from ``DeltaTModel/espenakMeeus2006`` elsewhere.
	public static let defaultContext = Context()

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TT = UT1 + ΔT(TT). Each evaluation shrinks the error by a factor of dΔT/dt,
		// at most about 2 × 10⁻⁶ even for the model in antiquity, so four suffice.
		var tt = julianDate
		for _ in 0 ..< 4 {
			let deltaT = try deltaT(at: tt, context: context)
			do throws(JulianDateError) {
				tt = try julianDate.adding(seconds: deltaT)
			}
			catch { throw TimescaleConversionError(error) }
		}
		return tt
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// UT1 = TT - ΔT(TT)
		let deltaT = try deltaT(at: julianDate, context: context)
		do throws(JulianDateError) {
			return try julianDate.adding(seconds: -deltaT)
		}
		catch { throw TimescaleConversionError(error) }
	}
}

extension UT1 {
	/// The data used to determine ΔT.
	public struct Context: Hashable, Sendable {
		/// Observed and predicted Earth orientation, used within its range.
		public var earthOrientation: EarthOrientationTable?
		/// Tabulated ΔT, used within its range outside ``earthOrientation``.
		public var deltaTTable: DeltaTTable?
		/// The model used outside ``earthOrientation`` and ``deltaTTable``, or `nil` to require
		/// tabulated values.
		public var model: DeltaTModel?

		/// Creates a UT1 context.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT, used outside `earthOrientation`.
		///   - model: The model used outside `earthOrientation` and `deltaTTable`, or `nil` to
		///     require tabulated values.
		public init(earthOrientation: EarthOrientationTable? = nil, deltaTTable: DeltaTTable? = .historic, model: DeltaTModel? = .espenakMeeus2006) {
			self.earthOrientation = earthOrientation
			self.deltaTTable = deltaTTable
			self.model = model
		}
	}
}

extension UT1 {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT.
	///
	/// - Parameters:
	///   - tt: A Julian Date in TT.
	///   - context: The source of ΔT.
	/// - Returns: ΔT, in seconds.
	/// - Throws: ``TimescaleConversionError/earthOrientationDataUnavailable`` if `tt` is
	///   outside the context's tables and the context has no model.
	public static func deltaT(at tt: JulianDate, context: Context) throws(TimescaleConversionError) -> Double {
		if let observed = context.earthOrientation?.deltaT(at: tt) {
			return observed.seconds
		}
		if let tabulated = context.deltaTTable?.deltaT(at: tt) {
			return tabulated.seconds
		}
		guard let model = context.model else { throw .earthOrientationDataUnavailable }
		return model.deltaT(decimalYear: tt.decimalYear)
	}
}
