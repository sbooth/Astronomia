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
/// ΔT comes from the context's ``EarthOrientationTable`` within its range, and from its
/// ``DeltaTModel`` elsewhere. The model and the observations can differ by several seconds,
/// so conversions are not continuous at the ends of the table.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No observations; ΔT from ``DeltaTModel/espenakMeeus2006``.
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
		/// The model used outside ``earthOrientation``, or `nil` to require observations.
		public var model: DeltaTModel?

		/// Creates a UT1 context.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - model: The model used outside `earthOrientation`, or `nil` to require
		///     observations.
		public init(earthOrientation: EarthOrientationTable? = nil, model: DeltaTModel? = .espenakMeeus2006) {
			self.earthOrientation = earthOrientation
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
	///   outside the context's table and the context has no model.
	public static func deltaT(at tt: JulianDate, context: Context) throws(TimescaleConversionError) -> Double {
		if let observed = context.earthOrientation?.deltaT(at: tt) {
			return observed.seconds
		}
		guard let model = context.model else { throw .earthOrientationDataUnavailable }
		return model.deltaT(decimalYear: tt.decimalYear)
	}
}
