//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A timescale that differs from TAI by a constant whole number of seconds.
///
/// Most GNSS system times are steered to a UTC realization at their start epoch and then run
/// without leap seconds, so each is TAI minus the leap seconds in effect at that epoch.
/// Conforming types only declare ``offsetFromTAI``; conversions are provided.
public protocol FixedTAIOffsetTimescale: Timescale where Context == Void {
	/// This timescale - TAI, in whole seconds.
	static var offsetFromTAI: Int { get }

	/// The start of week 0, as a Julian Date in this timescale.
	static var epoch: JulianDate { get }
}

extension FixedTAIOffsetTimescale {
	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let tai: JulianDate
		do throws(JulianDateError) {
			tai = try julianDate.adding(seconds: -offsetFromTAI)
		}
		catch { throw TimescaleConversionError(error) }
		return try TAI.toTT(tai)
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let tai = try TAI.fromTT(julianDate)
		do throws(JulianDateError) {
			return try tai.adding(seconds: offsetFromTAI)
		}
		catch { throw TimescaleConversionError(error) }
	}
}
