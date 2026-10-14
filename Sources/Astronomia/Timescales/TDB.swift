//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(ucrt)
import ucrt
#endif

/// Barycentric Dynamical Time (TDB).
///
/// TDB is a linear transformation of ``TCB`` (IAU 2006 Resolution B3), chosen so that it
/// stays close to TT at the geocenter. TDB - TT is periodic, dominated by an annual term of
/// 1.657 ms amplitude caused by the eccentricity of Earth's orbit.
///
/// TDB - TT is computed from a series in TT selected by the context's ``Model``. The series
/// are geocentric: the topocentric terms, at most about 2 µs, are omitted.
public enum TDB: Timescale {
	public static let abbreviation = "TDB"
	public static let defaultContext = Context()

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// The series takes TT. Evaluating it at TDB is off by about 10⁻¹² s, which a second
		// evaluation at the estimated TT removes, so the conversion inverts fromTT.
		do throws(JulianDateError) {
			let correctionUsingTDB = tdbMinusTT(at: julianDate, model: context.model)
			let estimate = try julianDate.adding(seconds: -correctionUsingTDB)
			let correction = tdbMinusTT(at: estimate, model: context.model)
			return try julianDate.adding(seconds: -correction)
		}
		catch { throw TimescaleConversionError(error) }
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		do throws(JulianDateError) {
			let correction = tdbMinusTT(at: julianDate, model: context.model)
			return try julianDate.adding(seconds: correction)
		}
		catch { throw TimescaleConversionError(error) }
	}
}

extension TDB {
	/// A model of TDB - TT.
	public enum Model: Hashable, Sendable {
		/// The seven-term series of USNO Circular 179 (Kaplan 2005), equation 2.6.
		///
		/// A truncation of Fairhead & Bretagnon (1990), within 10 µs of the full series from
		/// 1600 to 2200. The error grows slowly outside that range.
		case usnoCircular179
	}

	/// The data used to convert between TT and TDB.
	public struct Context: Hashable, Sendable {
		/// The model of TDB - TT.
		public let model: Model

		/// Creates a TDB context.
		///
		/// - Parameter model: The model of TDB - TT.
		public init(model: Model = .usnoCircular179) {
			self.model = model
		}
	}
}

extension TDB {
	/// Returns TDB − TT, in seconds, at the specified TT.
	///
	/// - Parameters:
	///   - tt: A Julian Date in TT.
	///   - model: The model of TDB − TT.
	/// - Returns: TDB − TT, in seconds.
	public static func tdbMinusTT(at tt: JulianDate, model: Model = .usnoCircular179) -> Double {
		switch model {
		case .usnoCircular179:
			circular179(julianCenturies: tt.julianCenturiesSinceJ2000)
		}
	}
}

extension TDB {
	/// TDB - TT, in seconds, from USNO Circular 179 equation 2.6.
	///
	/// - Parameter t: Julian centuries of TT from J2000.0.
	static func circular179(julianCenturies t: Double) -> Double {
		assert(t.isFinite, "Julian centuries must be finite")
		return 0.001_657 * sin(628.3076 * t + 6.2401)
			+ 0.000_022 * sin(575.3385 * t + 4.2970)
			+ 0.000_014 * sin(1256.6152 * t + 6.1969)
			+ 0.000_005 * sin(606.9777 * t + 4.0212)
			+ 0.000_005 * sin(52.9691 * t + 0.4444)
			+ 0.000_002 * sin(21.3299 * t + 5.5431)
			+ 0.000_010 * t * sin(628.3076 * t + 4.2490)
	}
}
