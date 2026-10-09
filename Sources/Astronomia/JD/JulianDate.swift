//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A Julian Date stored as a Julian day number plus a signed fraction of a day measured
/// from noon.
public struct JulianDate: Hashable, Sendable {
	/// The Julian day number of the civil day containing this date.
	public let julianDayNumber: Int
	/// The fraction of the day from noon, in the right-open interval [-0.5, 0.5).
	public let fractionFromNoon: Double

	/// Creates a Julian Date from parts that are already canonical.
	init(uncheckedJulianDayNumber julianDayNumber: Int, fractionFromNoon: Double) {
		assert(fractionFromNoon.isFinite, "Fraction from noon must be finite")
		assert(fractionFromNoon >= -0.5 && fractionFromNoon < 0.5, "Fraction from noon is outside the right-open interval [-0.5, 0.5)")
		self.julianDayNumber = julianDayNumber
		self.fractionFromNoon = fractionFromNoon
	}
}

extension JulianDate {
	/// JD of reference epoch J2000.0 (TT).
	static let J2000_JD: Double = 2_451_545.0
	/// JD of MJD zero.
	static let MJD0_JD: Double = 2_400_000.5

	/// Days per Julian year.
	static let daysPerJulianYear: Double = 365.25
	/// Days per Julian century.
	static let daysPerJulianCentury: Double = 36_525
	/// Days per tropical year, used for Besselian epochs.
	static let daysPerTropicalYear: Double = 365.242198781

	/// Seconds per day.
	static let secondsPerDay: Double = 60 * 60 * 24
}

extension JulianDate {
	/// J2000.0 epoch (JD 2451545.0).
	public static let J2000 = JulianDate(uncheckedJulianDayNumber: 2_451_545, fractionFromNoon: 0)
	/// B1900.0 epoch (JD 2415020.31352).
	public static let B1900 = JulianDate(uncheckedJulianDayNumber: 2_415_020, fractionFromNoon: 0.313_52)
	/// Modified Julian Day (MJD) zero (JD 2400000.5).
	public static let MJD0 = JulianDate(uncheckedJulianDayNumber: 2_400_001, fractionFromNoon: -0.5)
}

extension JulianDate {
	/// Creates a Julian Date `fractionFromNoon` days from `julianDayNumber`.
	public init(julianDayNumber: Int, fractionFromNoon: Double = 0) throws(JulianDateError) {
		guard fractionFromNoon.isFinite else { throw .nonFiniteValue }
		guard let f = normalizedSum(fractionFromNoon, 0) else { throw .dayCountNotRepresentable }
		let (n, overflow) = julianDayNumber.addingReportingOverflow(f.integral)
		guard !overflow else { throw .julianDayNumberNotRepresentable }
		self.init(uncheckedJulianDayNumber: n, fractionFromNoon: f.remainder)
	}

	/// Creates a Julian Date equal to `jd1 + jd2` from an IAU SOFA-style two-part Julian Date.
	public init(jd1: Double, jd2: Double = 0) throws(JulianDateError) {
		guard jd1.isFinite, jd2.isFinite else { throw .nonFiniteValue }
		guard let sum = normalizedSum(jd1, jd2) else { throw .julianDayNumberNotRepresentable }
		self.init(uncheckedJulianDayNumber: sum.integral, fractionFromNoon: sum.remainder)
	}

	/// Creates a Julian Date from a single value.
	/// - Note: The resolution is limited to ~40 µs near the present.
	public init(julianDate JD: Double) throws(JulianDateError) {
		try self.init(jd1: JD)
	}

	/// Creates a Julian Date equal to `mjd1 + mjd2` from an IAU SOFA-style two-part
	/// Modified Julian Date.
	/// - Note: For full precision pass the integral MJD in `mjd1` and the fraction of the day in
	///   `mjd2`.
	public init(mjd1: Double, mjd2: Double = 0) throws(JulianDateError) {
		self = try Self.MJD0.adding(days1: mjd1, days2: mjd2)
	}

	/// Creates a Julian Date from a single Modified Julian Date value.
	/// - Note: The resolution is limited to ~1 µs near the present.
	public init(modifiedJulianDate MJD: Double) throws(JulianDateError) {
		try self.init(mjd1: MJD)
	}

	/// Creates a Julian Date from the specified number of days relative to J2000.0.
	public init(daysSinceJ2000 days: Double) throws(JulianDateError) {
		self = try Self.J2000.adding(days: days)
	}

	/// Creates a Julian Date from a Julian epoch value, e.g. 2000.0.
	public init(julianEpoch epoch: Double) throws(JulianDateError) {
		guard epoch.isFinite else { throw .nonFiniteValue }
		let days = (epoch - 2000.0) * Self.daysPerJulianYear
		guard days.isFinite else { throw .dayCountNotRepresentable }
		self = try Self.J2000.adding(days: days)
	}

	/// Creates a Julian Date from a Besselian epoch value, e.g. 1950.0.
	public init(besselianEpoch epoch: Double) throws(JulianDateError) {
		guard epoch.isFinite else { throw .nonFiniteValue }
		let days = (epoch - 1900.0) * Self.daysPerTropicalYear
		guard days.isFinite else { throw .dayCountNotRepresentable }
		self = try Self.B1900.adding(days: days)
	}
}

extension JulianDate {
	/// The fraction of the day since midnight, in the right-open interval [0, 1).
	var fractionSinceMidnight: Double {
		// The exact value `fractionFromNoon + 0.5` lies in [0, 1) but can round to 1.
		// Clamping to `1.nextDown` keeps the instant in ``julianDayNumber``.
		min(fractionFromNoon + 0.5, Double(1).nextDown)
	}

	/// The Julian Date as a single value.
	/// - Important: This loses precision.
	public var julianDate: Double {
		Double(julianDayNumber) + fractionFromNoon
	}

	/// The Modified Julian Date (MJD) as a single value.
	/// - Note: Use ``parts(_:)`` with ``SplitMethod/fromMJD0`` for full precision.
	public var modifiedJulianDate: Double {
		(differenceAsDouble(julianDayNumber, Self.MJD0.julianDayNumber) + 0.5) + fractionFromNoon
	}

	/// Days from J2000.0 as a single value.
	/// - Note: Use ``parts(_:)`` with ``SplitMethod/fromJ2000`` for full precision.
	public var daysSinceJ2000: Double {
		differenceAsDouble(julianDayNumber, Self.J2000.julianDayNumber) + (fractionFromNoon /*- Self.J2000.fraction*/)
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
		let days = differenceAsDouble(julianDayNumber, Self.B1900.julianDayNumber) + (fractionFromNoon - Self.B1900.fractionFromNoon)
		return 1900.0 + days / Self.daysPerTropicalYear
	}
}

extension JulianDate {
	/// Ways of dividing a Julian Date between two doubles.
	///
	/// A split's `jd1` is exact when it is exactly representable as a `Double`:
	/// 1. A whole number of days up to 2^53 in magnitude (about 2.5 × 10^13 years), or
	/// 2. A half-integer (midnight) below 2^52 in magnitude (about 1.2 × 10^13 years).
	///
	/// Beyond that, `jd1` is rounded to the nearest `Double`, so `jd1 + jd2` only approximates
	/// this Julian Date.
	///
	/// `jd2` can also round. ``SplitMethod/dateAndTime`` and ``SplitMethod/fromMJD0`` round the
	/// time of day by up to 2^-54 days; it is exact from midnight to 06:00.
	///
	/// ``SplitMethod/julianDate``, ``SplitMethod/j2000`` and ``SplitMethod/mjd`` hold a single
	/// value, limited by the precision of one `Double`.
	public enum SplitMethod: Sendable {
		/// SOFA JD method: `jd1` holds the whole JD, `jd2` is zero.
		case julianDate
		/// SOFA J2000 method: `jd1` is J2000.0 (2451545.0), `jd2` is days from J2000.0.
		case j2000
		/// SOFA MJD method: `jd1` is MJD zero (2400000.5), `jd2` is the MJD.
		case mjd
		/// SOFA date and time method: `jd1` is the JD of the preceding midnight,
		/// `jd2` is the fraction of the day from midnight in the right-open interval [0, 1).
		case dateAndTime
		/// `jd1` is the integral Julian day number, `jd2` is the fraction of the day from
		/// noon in the right-open interval [-0.5, 0.5).
		case dayAndFraction
		/// `jd1` is the integral number of days from J2000.0, `jd2` is the fraction of the day
		/// from noon in the right-open interval [-0.5, 0.5).
		case fromJ2000
		/// `jd1` is the integral number of days from MJD zero, `jd2` is the fraction of the day
		/// from midnight in the right-open interval [0, 1).
		case fromMJD0
	}

	/// Returns the parts of this Julian Date divided using the specified split method.
	public func parts(_ method: SplitMethod) -> (jd1: Double, jd2: Double) {
		switch method {
		case .julianDate:
			return (Double(julianDayNumber) + fractionFromNoon, 0)
		case .j2000:
			return (Self.J2000_JD, daysSinceJ2000)
		case .mjd:
			return (Self.MJD0_JD, modifiedJulianDate)
		case .dateAndTime:
			return (Double(julianDayNumber) - 0.5, fractionSinceMidnight)
		case .dayAndFraction:
			return (Double(julianDayNumber), fractionFromNoon)
		case .fromJ2000:
			return (differenceAsDouble(julianDayNumber, Self.J2000.julianDayNumber), fractionFromNoon)
		case .fromMJD0:
			return (differenceAsDouble(julianDayNumber, Self.MJD0.julianDayNumber), fractionSinceMidnight)
		}
	}
}

extension JulianDate {
	public func adding(days: Int) throws(JulianDateError) -> JulianDate {
		let (day, overflow) = self.julianDayNumber.addingReportingOverflow(days)
		guard !overflow else { throw .julianDayNumberNotRepresentable }
		return JulianDate(uncheckedJulianDayNumber: day, fractionFromNoon: fractionFromNoon)
	}

	/// Returns a date advanced by the two-part interval `days1 + days2`.
	public func adding(days1: Double, days2: Double) throws(JulianDateError) -> JulianDate {
		try adding(Interval(days1: days1, days2: days2))
	}

	public func adding(days: Double) throws(JulianDateError) -> JulianDate {
		try adding(days1: days, days2: 0)
	}
}

extension JulianDate {
	public func adding(seconds: Int) throws(JulianDateError) -> JulianDate {
		let (days, remainder) = seconds.quotientAndRemainder(dividingBy: 86_400)
		let (day, overflow) = self.julianDayNumber.addingReportingOverflow(days)
		guard !overflow else { throw .julianDayNumberNotRepresentable }
		return try JulianDate(julianDayNumber: day, fractionFromNoon: fractionFromNoon + Double(remainder) / 86_400)
	}

	/// Returns a date advanced by the two-part interval `seconds1 + seconds2`.
	public func adding(seconds1: Double, seconds2: Double) throws(JulianDateError) -> JulianDate {
		try adding(Interval(seconds1: seconds1, seconds2: seconds2))
	}

	public func adding(seconds: Double) throws(JulianDateError) -> JulianDate {
		try adding(seconds1: seconds, seconds2: 0)
	}
}

extension JulianDate {
	/// Returns `true` if the specified Julian Date is within the specified tolerance of this Julian
	/// Date, assuming 86,400 seconds per day.
	///
	/// Use this instead of `==` when comparing dates that took different computational paths, e.g.
	/// a JD-method value against a date-and-time split.
	///
	/// - Precondition: The specified tolerance is non-negative and not NaN.
	public func isApproximatelyEqual(to other: JulianDate, toleranceSeconds: Double) -> Bool {
		precondition(toleranceSeconds >= 0, "Tolerance must be non-negative")
		guard let interval = try? interval(to: other) else {
			let days = (Double(julianDayNumber) - Double(other.julianDayNumber)) + (fractionFromNoon - other.fractionFromNoon)
			return (days * Self.secondsPerDay).magnitude <= toleranceSeconds
		}
		return interval.inSeconds.magnitude <= toleranceSeconds
	}
}

extension JulianDate: Comparable {
	public static func < (lhs: JulianDate, rhs: JulianDate) -> Bool {
		(lhs.julianDayNumber, lhs.fractionFromNoon) < (rhs.julianDayNumber, rhs.fractionFromNoon)
	}
}

extension JulianDate: CustomStringConvertible {
	public var description: String {
		if fractionFromNoon == 0 {
			return "JD \(julianDayNumber)"
		} else {
			return "JD \(julianDayNumber) \(fractionFromNoon < 0 ? "-" : "+") \(abs(fractionFromNoon))"
		}
	}
}

extension JulianDate: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate(julianDayNumber: \(julianDayNumber), fractionFromNoon: \(fractionFromNoon))"
	}
}

/// Returns the difference between two `Int` values as a `Double`.
func differenceAsDouble(_ lhs: Int, _ rhs: Int) -> Double {
	let (difference, overflow) = lhs.subtractingReportingOverflow(rhs)
	guard overflow else { return Double(difference) }
	// Overflow means the operands have opposite signs, so the result is ±(|lhs| + |rhs|) with the
	// sign of lhs. The magnitude is at most 2^64 - 1, exact in UInt, and converts with one
	// rounding. Converting each operand to Double first would round up to three times.
	if lhs >= 0 {
		return Double(lhs.magnitude + rhs.magnitude)
	}
	return -Double(lhs.magnitude + rhs.magnitude)
}

extension JulianDate: Codable {
	private enum CodingKeys: String, CodingKey {
		case julianDayNumber, fractionFromNoon
	}

	/// Decodes and validates a Julian Date.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let julianDayNumber = try container.decode(Int.self, forKey: .julianDayNumber)
		let fractionFromNoon = try container.decode(Double.self, forKey: .fractionFromNoon)

		do throws(JulianDateError) {
			self = try JulianDate(julianDayNumber: julianDayNumber, fractionFromNoon: fractionFromNoon)
		} catch .nonFiniteValue {
			throw DecodingError.dataCorruptedError(forKey: .fractionFromNoon, in: container, debugDescription: "Fraction from noon must be finite")
		} catch .dayCountNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .fractionFromNoon, in: container, debugDescription: "The fraction from noon's day count is not representable")
		} catch .julianDayNumberNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .julianDayNumber, in: container, debugDescription: "The Julian day number is not representable")
		}
	}
}
