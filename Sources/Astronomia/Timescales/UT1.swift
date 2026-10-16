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
/// ΔT comes from the context's ``DeltaTSource``. By default that is Earth orientation data,
/// if supplied, then ``DeltaTTable/historic``, with ``DeltaTModel/espenakMeeus2006`` offset to
/// join the data continuously outside them. See
/// ``Context/init(earthOrientation:deltaTTable:model:)``.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No Earth orientation data; ΔT from ``DeltaTTable/historic`` from 1657.0 to 1984.5 and
	/// from ``DeltaTModel/espenakMeeus2006``, offset to join the table, elsewhere.
	public static let defaultContext = Context()

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TT = UT1 + ΔT(TT). Each evaluation shrinks the error by a factor of dΔT/dt,
		// at most about 2 × 10^-6 even for the model in antiquity, so four suffice.
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

		/// Creates a UT1 context that takes ΔT from Earth orientation data, a ΔT table, and a
		/// model.
		///
		/// ΔT comes from `earthOrientation` within its range, then from `deltaTTable` within its
		/// range. Past the end of `earthOrientation`, and before the start of `deltaTTable`, ΔT
		/// follows `model` offset to join the data continuously. Between `deltaTTable` and
		/// `earthOrientation`, or after `deltaTTable` without `earthOrientation`, ΔT follows
		/// `model` offset to join `deltaTTable`.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT.
		///   - model: The model used outside the data, or `nil` to require tabulated values.
		public init(earthOrientation: EarthOrientationTable? = nil, deltaTTable: DeltaTTable? = .historic, model: DeltaTModel? = .espenakMeeus2006) {
			let join = model.map(DeltaTExtrapolation.Method.model)
			var sources: [any DeltaTSource] = []
			if let earthOrientation {
				sources.append(DeltaTExtrapolation(earthOrientation, after: join))
			}
			if let deltaTTable {
				sources.append(DeltaTExtrapolation(deltaTTable, before: join, after: join))
			}
			if let model {
				sources.append(model)
			}
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
	///   - ``TimescaleConversionError/deltaTUnavailable`` if the context's source
	///     does not cover `tt`.
	///   - ``TimescaleConversionError/nonFiniteValue`` if the source returns NaN or infinity.
	public static func deltaT(at tt: JulianDate, context: Context) throws(TimescaleConversionError) -> Double {
		guard let deltaT = context.deltaT.deltaT(at: tt) else { throw .deltaTUnavailable }
		guard deltaT.isFinite else { throw .nonFiniteValue }
		return deltaT
	}
}
