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
/// ΔT comes from the context's ``DeltaTSource``. By default that is a ``DeltaTSourceList`` of
/// Earth orientation data, if supplied, then ``DeltaTTable/historic``, then
/// ``DeltaTModel/espenakMeeus2006``. Sources can differ where one hands over to the next, by
/// up to several seconds between the model and the tables, so conversions are not
/// continuous there.
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
	/// The source of ΔT.
	public struct Context: Sendable {
		/// The source of ΔT.
		public var deltaT: any DeltaTSource

		/// Creates a UT1 context with the specified source of ΔT.
		///
		/// - Parameter deltaT: The source of ΔT.
		public init(deltaT: any DeltaTSource) {
			self.deltaT = deltaT
		}

		/// Creates a UT1 context that takes ΔT from the first of the specified sources that
		/// covers the date.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation, used within its range.
		///   - deltaTTable: Tabulated ΔT, used within its range outside `earthOrientation`.
		///   - model: The model used outside `earthOrientation` and `deltaTTable`, or `nil` to
		///     require tabulated values.
		public init(earthOrientation: EarthOrientationTable? = nil, deltaTTable: DeltaTTable? = .historic, model: DeltaTModel? = .espenakMeeus2006) {
			var sources: [any DeltaTSource] = []
			if let earthOrientation { sources.append(earthOrientation) }
			if let deltaTTable { sources.append(deltaTTable) }
			if let model { sources.append(model) }
			self.init(deltaT: DeltaTSourceList(sources))
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
	/// - Throws:
	///   - ``TimescaleConversionError/earthOrientationDataUnavailable`` if the context's source
	///     does not cover `tt`.
	///   - ``TimescaleConversionError/nonFiniteValue`` if the source returns NaN or infinity.
	public static func deltaT(at tt: JulianDate, context: Context) throws(TimescaleConversionError) -> Double {
		guard let deltaT = context.deltaT.deltaT(at: tt) else { throw .deltaTUnavailable }
		guard deltaT.isFinite else { throw .nonFiniteValue }
		return deltaT
	}
}
