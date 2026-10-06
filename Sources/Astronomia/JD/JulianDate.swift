//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A Julian Date stored as an integral Julian day number plus a signed fraction of a day measured
/// from noon.
///
/// A single double near JD 2.45e6 has a resolution of ~40 µs. Storing the day number and the
/// fraction separately gives a resolution of ~5 ps: the fraction never exceeds half a day in
/// magnitude, so its ulp is at most 2^-54 days.
///
/// A Julian Date may be created from any two-part split following the IAU SOFA convention (the date
/// is `jd1 + jd2`), but is always stored in canonical form: `day` is integral and `fraction` lies
/// in the right-open interval [-0.5, 0.5). `day` is the Julian day number of the civil day
/// containing the instant; that day begins at midnight `day - 0.5` and ends at midnight
/// `day + 0.5`. Use ``parts(_:)`` to obtain another split. SOFA's recommended splits, in rough
/// order of precision, are:
///
/// | `jd1` | `jd2` | Method | Precision |
/// | --- | --- | --- | --- |
/// | 2450123.7 | 0.0 | JD | Worst |
/// | 2451545.0 | -1421.3 | J2000 | Good |
/// | 2400000.5 | 50123.2 | MJD | Good |
/// | 2450123.5 | 0.2 | Date & time | Best |
///
/// ## Range and precision
///
/// There is no range limit: every finite date is representable. Integral and fractional parts are
/// accumulated separately, so constructing a date or adding to one rounds at most once per
/// fractional input, by at most 2^-54 days, as long as the integral parts involved stay below 2^53
/// in magnitude (about ±2.5 × 10^13 years). Beyond that the day number itself rounds, and the date
/// degrades gracefully, like a plain `Double`, instead of failing.
///
/// Single-value inputs and outputs are limited by the precision of a single `Double`. To keep
/// the full resolution, use the two-part forms: ``init(jd1:jd2:)``, ``init(mjd1:mjd2:)``,
/// ``adding(days:plus:)``, ``adding(seconds:plus:)``, ``parts(_:)``, and ``Interval`` for
/// differences and offsets.
///
/// ## Failure
///
/// The only failure is a non-finite result: a non-finite input or a result that overflows to
/// infinity. Each trapping API has a failable counterpart that returns `nil` instead.
public struct JulianDate: Sendable {
	/// The integral Julian day number of the civil day containing this instant.
	///
	/// The day begins at midnight `day - 0.5` and is centered on noon, `day` itself.
	public let day: Double

	/// The fraction of a day from noon of ``day``, in the right-open interval [-0.5, 0.5).
	public let fraction: Double

	/// Creates a Julian Date from parts that are already canonical.
	init(uncheckedDay day: Double, fraction: Double) {
		assert(day.isFinite && day == day.rounded(), "Day must be finite and integral")
		assert(fraction >= -0.5 && fraction < 0.5, "Fraction is outside the right-open interval [-0.5, 0.5)")
		self.day = day
		self.fraction = fraction
	}
}

extension JulianDate {
	/// JD of reference epoch J2000.0 (TT).
	static let J2000_JD: Double = 2_451_545
	/// JD of MJD zero.
	static let MJD0_JD: Double = 2_400_000.5
	/// MJD of Besselian epoch B1900.0.
	static let B1900_MJD: Double = 15_019.81352

	/// Days from B1900.0 to J2000.0.
	static let daysFromB1900ToJ2000: Double = 36_524.68648

	/// Days per Julian year.
	static let daysPerJulianYear: Double = 365.25
	/// Days per Julian century.
	static let daysPerJulianCentury: Double = 36_525
	/// Days per tropical year, used for Besselian epochs.
	static let daysPerTropicalYear: Double = 365.242198781

	/// Seconds per day.
	static let secondsPerDay: Double = 60 * 60 * 24

	/// J2000.0 (2000-01-01T12:00:00).
	public static let J2000 = JulianDate(uncheckedDay: J2000_JD, fraction: 0)
}

extension JulianDate {
	/// Creates a Julian Date from two parts in any split, returning `nil` if the result is not
	/// finite.
	public init?(validatingJD1 jd1: Double, jd2: Double = 0) {
		var a = Accumulator()
		a.add(days: jd1) // From zero: no rounding.
		a.add(days: jd2)
		self.init(a)
	}

	/// Creates a Julian Date equal to `jd1 + jd2`.
	/// - Precondition: Both parts are finite and their sum does not overflow.
	public init(jd1: Double, jd2: Double = 0) {
		guard let date = Self(validatingJD1: jd1, jd2: jd2) else {
			preconditionFailure("Julian Date \(jd1) + \(jd2) is not finite")
		}
		self = date
	}

	/// Creates a Julian Date from a single value, returning `nil` if the value is not finite.
	/// - Note: The resolution is limited to ~40 µs near the present. Use
	///   ``init(validatingJD1:jd2:)`` for full precision.
	public init?(validatingJulianDate JD: Double) {
		self.init(validatingJD1: JD)
	}

	/// Creates a Julian Date from a single value.
	/// - Note: The resolution is limited to ~40 µs near the present. Use ``init(jd1:jd2:)`` for
	///   full precision.
	/// - Precondition: The value is finite.
	public init(julianDate JD: Double) {
		self.init(jd1: JD)
	}

	/// Creates a Julian Date from a Modified Julian Date equal to `mjd1 + mjd2`, apportioned in any
	/// convenient way, returning `nil` if the result is not finite.
	/// - Note: For full precision pass the integral MJD in `mjd1` and the fraction of the day in
	///   `mjd2`.
	public init?(validatingMJD1 mjd1: Double, mjd2: Double = 0) {
		var a = Accumulator()
		a.add(days: Self.MJD0_JD)
		a.add(days: mjd1)
		a.add(days: mjd2)
		self.init(a)
	}

	/// Creates a Julian Date from a Modified Julian Date equal to `mjd1 + mjd2`, apportioned in any
	/// convenient way.
	/// - Note: For full precision pass the integral MJD in `mjd1` and the fraction of the day in
	///   `mjd2`.
	/// - Precondition: Both parts are finite and the result does not overflow.
	public init(mjd1: Double, mjd2: Double = 0) {
		guard let date = Self(validatingMJD1: mjd1, mjd2: mjd2) else {
			preconditionFailure("Modified Julian Date \(mjd1) + \(mjd2) is not finite")
		}
		self = date
	}

	/// Creates a Julian Date from a single Modified Julian Date value, returning `nil` if the value
	/// is not finite.
	/// - Note: The resolution is limited to ~1 µs near the present. Use
	///   ``init(validatingMJD1:mjd2:)`` for full precision.
	public init?(validatingModifiedJulianDate MJD: Double) {
		self.init(validatingMJD1: MJD)
	}

	/// Creates a Julian Date from a single Modified Julian Date value.
	/// - Note: The resolution is limited to ~1 µs near the present. Use ``init(mjd1:mjd2:)`` for
	///   full precision.
	/// - Precondition: The value is finite.
	public init(modifiedJulianDate MJD: Double) {
		self.init(mjd1: MJD)
	}

	/// Creates a Julian Date from the specified number of days relative to J2000.0,
	/// returning `nil` if the result is not finite.
	///
	/// For full precision use `JulianDate.J2000.addingIfRepresentable(days:plus:)`.
	public init?(validatingDaysSinceJ2000 days: Double) {
		guard let date = Self.J2000.addingIfRepresentable(days: days) else {
			return nil
		}
		self = date
	}

	/// Creates a Julian Date from the specified number of days relative to J2000.0.
	///
	/// For full precision use `JulianDate.J2000.adding(days:plus:)`.
	/// - Precondition: The number of days is finite.
	public init(daysSinceJ2000 days: Double) {
		guard let date = Self(validatingDaysSinceJ2000: days) else {
			preconditionFailure("\(days) days from J2000.0 is not finite")
		}
		self = date
	}

	/// Creates a Julian Date from a Julian epoch value, e.g. 2000.0, returning `nil` if the result
	/// is not finite.
	public init?(validatingJulianEpoch epoch: Double) {
		guard let date = Self.J2000.addingIfRepresentable(days: (epoch - 2000.0) * Self.daysPerJulianYear) else {
			return nil
		}
		self = date
	}

	/// Creates a Julian Date from a Julian epoch value, e.g. 2000.0.
	/// - Precondition: The epoch is finite and the result does not overflow.
	public init(julianEpoch epoch: Double) {
		guard let date = Self(validatingJulianEpoch: epoch) else {
			preconditionFailure("Julian epoch \(epoch) is not representable")
		}
		self = date
	}

	/// Creates a Julian Date from a Besselian epoch value, e.g. 1950.0, returning `nil` if the
	/// result is not finite.
	public init?(validatingBesselianEpoch epoch: Double) {
		var a = Accumulator()
		a.add(days: Self.MJD0_JD)
		a.add(days: Self.B1900_MJD)
		a.add(days: (epoch - 1900.0) * Self.daysPerTropicalYear)
		self.init(a)
	}

	/// Creates a Julian Date from a Besselian epoch value, e.g. 1950.0.
	/// - Precondition: The epoch is finite and the result does not overflow.
	public init(besselianEpoch epoch: Double) {
		guard let date = Self(validatingBesselianEpoch: epoch) else {
			preconditionFailure("Besselian epoch \(epoch) is not representable")
		}
		self = date
	}
}

extension JulianDate {
	/// The Julian Date collapsed to a single value.
	/// - Note: This loses precision.
	public var julianDate: Double {
		day + fraction
	}

	/// The Modified Julian Date (MJD) as a single value. Use ``parts(_:)`` with
	/// ``SplitMethod/fromMJD0`` for full precision.
	public var modifiedJulianDate: Double {
		// (day - MJD0_JD) is a half-integer, exact while its magnitude is below 2^52.
		(day - Self.MJD0_JD) + fraction
	}

	/// Days from J2000.0 as a single value. Use ``parts(_:)`` with
	/// ``SplitMethod/fromJ2000`` for full precision.
	public var daysSinceJ2000: Double {
		(day - Self.J2000_JD) + fraction
	}

	/// Julian centuries from J2000.0.
	public var julianCenturiesSinceJ2000: Double {
		daysSinceJ2000 / Self.daysPerJulianCentury
	}

	/// Julian epoch.
	public var julianEpoch: Double {
		2000.0 + daysSinceJ2000 / Self.daysPerJulianYear
	}

	/// Besselian epoch.
	public var besselianEpoch: Double {
		1900.0 + ((day - Self.J2000_JD) + (fraction + Self.daysFromB1900ToJ2000)) / Self.daysPerTropicalYear
	}
}

extension JulianDate {
	/// Ways of dividing a Julian Date between two doubles.
	public enum SplitMethod: Sendable {
		/// `jd1` holds the whole JD, `jd2` is zero.
		/// - Note: `jd1` is rounded to a single `Double` (~40 µs near the present).
		case julianDate
		/// `jd1` is J2000.0 (2451545.0), `jd2` is days from J2000.0.
		/// - Note: `jd2` is rounded to a single `Double`. Use ``fromJ2000`` for full precision.
		case j2000
		/// `jd1` is MJD zero (2400000.5), `jd2` is the MJD.
		/// - Note: `jd2` is rounded to a single `Double`. Use ``fromMJD0`` for full precision.
		case mjd
		/// `jd1` is the JD of the preceding midnight, `jd2` is the fraction of the day from
		/// midnight in the right-open interval [0, 1).
		/// - Note: `jd1` is exact for |`day`| < 2^52. `jd2` is exact from midnight to 06:00
		///   (`fraction` <= -0.25) and otherwise may round by at most 2^-54 days.
		case dateAndTime
		/// `jd1` is the integral Julian day number, `jd2` is the fraction of the day from
		/// noon in the right-open interval [-0.5, 0.5).
		/// - Note: This split is always exact.
		case dayAndFraction
		/// `jd1` is the integral number of days from J2000.0, `jd2` is the fraction of the day
		/// from noon in the right-open interval [-0.5, 0.5).
		/// - Note: `jd1` is exact when its magnitude is below 2^53. `jd2` is always exact.
		case fromJ2000
		/// `jd1` is the integral number of days from MJD zero, `jd2` is the fraction of the day
		/// from midnight in the right-open interval [0, 1).
		/// - Note: `jd1` is exact for |`day`| < 2^52. `jd2` is exact from midnight to 06:00
		///   (`fraction` <= -0.25) and otherwise may round by at most 2^-54 days.
		case fromMJD0
	}

	/// Returns the parts of this Julian Date divided using the specified split method.
	public func parts(_ method: SplitMethod) -> (jd1: Double, jd2: Double) {
		switch method {
		case .julianDate:
			return (day + fraction, 0)
		case .j2000:
			return (Self.J2000_JD, (day - Self.J2000_JD) + fraction)
		case .mjd:
			return (Self.MJD0_JD, (day - Self.MJD0_JD) + fraction)
		case .dateAndTime:
			let midnight = day - 0.5 // Exact for |day| < 2^52.
			let dayFraction = fraction + 0.5 // Exact sum in [0, 1); rounds into [0, 1].
			if dayFraction == 1 {
				return (midnight + 1, 0)
			}
			return (midnight, dayFraction)
		case .dayAndFraction:
			return (day, fraction)
		case .fromJ2000:
			return (day - Self.J2000_JD, fraction)
		case .fromMJD0:
			let (midnight, dayFraction) = parts(.dateAndTime)
			// Both are half-integers, so the difference is an exact integer for |day| < 2^52.
			return (midnight - Self.MJD0_JD, dayFraction)
		}
	}
}

extension JulianDate {
	/// Returns the Julian Date offset by `days1 + days2` days, apportioned in any convenient way,
	/// or `nil` if the result is not finite.
	///
	/// For full precision pass whole days in `days1` and the remainder in `days2`.
	public func addingIfRepresentable(days days1: Double, plus days2: Double = 0) -> JulianDate? {
		var a = Accumulator(self)
		a.add(days: days1)
		a.add(days: days2)
		return JulianDate(a)
	}

	/// Returns the Julian Date offset by `days1 + days2` days, apportioned in any convenient way.
	///
	/// For full precision pass whole days in `days1` and the remainder in `days2`.
	/// - Precondition: Both parts are finite and the result does not overflow.
	public func adding(days days1: Double, plus days2: Double = 0) -> JulianDate {
		guard let date = addingIfRepresentable(days: days1, plus: days2) else {
			preconditionFailure("Adding \(days1) + \(days2) days to \(self) is not finite")
		}
		return date
	}

	/// Returns the Julian Date offset by `seconds1 + seconds2` seconds, apportioned in any
	/// convenient way and assuming 86,400 seconds per day, or `nil` if the result is not finite.
	///
	/// For full precision pass whole seconds in `seconds1` and the fraction of a second in
	/// `seconds2`.
	public func addingIfRepresentable(seconds seconds1: Double, plus seconds2: Double = 0) -> JulianDate? {
		var a = Accumulator(self)
		a.add(seconds: seconds1)
		a.add(seconds: seconds2)
		return JulianDate(a)
	}

	/// Returns the Julian Date offset by `seconds1 + seconds2` seconds, apportioned in any
	/// convenient way and assuming 86,400 seconds per day.
	///
	/// For full precision pass whole seconds in `seconds1` and the fraction of a second in
	/// `seconds2`.
	/// - Precondition: Both parts are finite and the result does not overflow.
	public func adding(seconds seconds1: Double, plus seconds2: Double = 0) -> JulianDate {
		guard let date = addingIfRepresentable(seconds: seconds1, plus: seconds2) else {
			preconditionFailure("Adding \(seconds1) + \(seconds2) seconds to \(self) is not finite")
		}
		return date
	}
}

extension JulianDate {
	/// Returns the Julian Date offset by a number of days.
	/// - Precondition: The number of days is finite and the result does not overflow.
	public static func + (lhs: JulianDate, days: Double) -> JulianDate {
		lhs.adding(days: days)
	}

	/// Returns the Julian Date offset by a negative number of days.
	/// - Precondition: The number of days is finite and the result does not overflow.
	public static func - (lhs: JulianDate, days: Double) -> JulianDate {
		lhs.adding(days: -days)
	}
}

extension JulianDate {
	/// Returns `true` if the specified Julian Date is within the specified tolerance of this Julian
	/// Date, assuming 86,400 seconds per day.
	///
	/// Use this instead of `==` when comparing dates that took different computational paths, e.g.
	/// a JD-method value against a date-and-time split.
	///
	/// This is not an equivalence relation (it is not transitive), so it is not a substitute for
	/// `==` in `Hashable` or `Set` contexts.
	///
	/// - Precondition: The specified tolerance is non-negative and not NaN.
	public func isApproximatelyEqual(to other: JulianDate, toleranceSeconds: Double) -> Bool {
		precondition(toleranceSeconds >= 0, "Tolerance must be non-negative")
		guard let i = intervalIfRepresentable(since: other) else {
			return false
		}
		return i.inSeconds.magnitude <= toleranceSeconds
	}
}

// The stored parts are canonical, so equality and hashing can be synthesized.
extension JulianDate: Hashable {}

extension JulianDate: Comparable {
	// Canonical form makes lexicographic order chronological: a later day always wins, because
	// fractions span less than one day.
	public static func < (lhs: JulianDate, rhs: JulianDate) -> Bool {
		(lhs.day, lhs.fraction) < (rhs.day, rhs.fraction)
	}
}

extension JulianDate: CustomStringConvertible {
	public var description: String {
		if fraction == 0 {
			return "JD \(day)"
		} else {
			return "JD \(day) \(fraction < 0 ? "-" : "+") \(abs(fraction))"
		}
	}
}

extension JulianDate: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate(day: \(day), fraction: \(fraction))"
	}
}

extension JulianDate: Codable {
	// Keys keep SOFA naming; any split decodes correctly.
	private enum CodingKeys: String, CodingKey {
		case jd1, jd2
	}

	/// Decodes a Julian Date from any split of `jd1 + jd2`; `jd2` defaults to 0 if absent.
	/// - throws: `DecodingError.dataCorrupted` if the result is not finite.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let jd1 = try container.decode(Double.self, forKey: .jd1)
		let jd2 = try container.decodeIfPresent(Double.self, forKey: .jd2) ?? 0
		guard let julianDate = JulianDate(validatingJD1: jd1, jd2: jd2) else {
			throw DecodingError.dataCorruptedError(forKey: .jd1, in: container, debugDescription: "Julian Date parts must be finite and their sum must not overflow (jd1: \(jd1), jd2: \(jd2))")
		}
		self = julianDate
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(day, forKey: .jd1)
		try container.encode(fraction, forKey: .jd2)
	}
}
