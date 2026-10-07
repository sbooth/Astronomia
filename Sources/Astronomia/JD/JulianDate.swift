//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

public enum JulianDateError: Error, Hashable, Sendable {
	/// An input is NaN or infinite.
	case nonFiniteInput
	/// The resulting Julian Date's Julian day number is not representable as an `Int`.
	case dateOutOfRange
	/// The resulting interval's whole days are not representable as an `Int`.
	case intervalOutOfRange
}

/// A Julian Date stored as an integral Julian day number plus a signed fraction of a day measured
/// from noon.
public struct JulianDate: Sendable, Hashable {
	/// The Julian day number corresponding to the noon boundary.
	public let jdn: Int
	/// The fraction of a day from noon of ``jdn``, in the right-open interval [-0.5, 0.5).
	public let fraction: Double

	/// Creates a Julian Date from parts that are already canonical.
	init(uncheckedJDN J: Int, fraction: Double) {
		assert(fraction >= -0.5 && fraction < 0.5, "Fraction must be in the right-open interval [-0.5, 0.5)")
		self.jdn = J
		self.fraction = fraction
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
	public static let J2000 = JulianDate(uncheckedJDN: 2_451_545, fraction: 0)
	/// B1900.0 epoch (JD 2415020.31352).
	public static let B1900 = JulianDate(uncheckedJDN: 2_415_020, fraction: 0.313_52)
	/// Modified Julian Day (MJD) zero (JD 2400000.5).
	public static let MJD0 = JulianDate(uncheckedJDN: 2_400_001, fraction: -0.5)
}

extension JulianDate {
	/// Creates a Julian Date `fraction` days from noon of Julian day number `jdn`.
	public init(jdn: Int, fraction: Double = 0) throws(JulianDateError) {
		guard fraction.isFinite else { throw .nonFiniteInput }
		guard let f = normalizedSum(fraction, 0) else { throw .dateOutOfRange }
		let (n, overflow) = jdn.addingReportingOverflow(f.integral)
		guard !overflow else { throw .dateOutOfRange }
		self.init(uncheckedJDN: n, fraction: f.remainder)
	}

	/// Creates a Julian Date equal to `jd1 + jd2` from an IAU SOFA-style two-part Julian Date.
	public init(jd1: Double, jd2: Double = 0) throws(JulianDateError) {
		guard jd1.isFinite, jd2.isFinite else { throw .nonFiniteInput }
		guard let sum = normalizedSum(jd1, jd2) else { throw .dateOutOfRange }
		self.jdn = sum.integral
		self.fraction = sum.remainder
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
		self = try Self.J2000.adding(days: (epoch - 2000.0) * Self.daysPerJulianYear)
	}

	/// Creates a Julian Date from a Besselian epoch value, e.g. 1950.0.
	public init(besselianEpoch epoch: Double) throws(JulianDateError) {
		self = try Self.B1900.adding(days: (epoch - 1900.0) * Self.daysPerTropicalYear)
	}
}

extension JulianDate {
	/// The Julian Date as a single value.
	/// - Important: This loses precision.
	public var julianDate: Double {
		Double(jdn) + fraction
	}

	/// The Modified Julian Date (MJD) as a single value.
	/// - Note: Use ``parts(_:)`` with ``SplitMethod/fromMJD0`` for full precision.
	public var modifiedJulianDate: Double {
		(differenceAsDouble(jdn, Self.MJD0.jdn) + 0.5) + fraction
	}

	/// Days from J2000.0 as a single value.
	/// - Note: Use ``parts(_:)`` with ``SplitMethod/fromJ2000`` for full precision.
	public var daysSinceJ2000: Double {
		differenceAsDouble(jdn, Self.J2000.jdn) + (fraction /*- Self.J2000.fraction*/)
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
		let days = differenceAsDouble(jdn, Self.B1900.jdn) + (fraction - Self.B1900.fraction)
		return 1900.0 + days / Self.daysPerTropicalYear
	}
}

extension JulianDate {
	/// Ways of dividing a Julian Date between two doubles.
	public enum SplitMethod: Sendable {
		/// SOFA JD method: `jd1` holds the whole JD, `jd2` is zero.
		case julianDate
		/// SOFA J2000 method: `jd1` is J2000.0 (2451545.0), `jd2` is days from J2000.0.
		case j2000
		/// SOFA MJD method: `jd1` is MJD zero (2400000.5), `jd2` is the MJD.
		case mjd
		/// SOFA Date and Time method: `jd1` is the JD of the preceding midnight,
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
			return (Double(jdn) + fraction, 0)
		case .j2000:
			return (Self.J2000_JD, daysSinceJ2000)
		case .mjd:
			return (Self.MJD0_JD, modifiedJulianDate)
		case .dateAndTime:
			let fraction = self.fraction + 0.5
			return fraction == 1 ? (Double(jdn) + 0.5, 0) : (Double(jdn) - 0.5, fraction)
		case .dayAndFraction:
			return (Double(jdn), fraction)
		case .fromJ2000:
			return (differenceAsDouble(jdn, Self.J2000.jdn), fraction)
		case .fromMJD0:
			let fraction = self.fraction + 0.5
			let jdn = differenceAsDouble(self.jdn, Self.MJD0.jdn)
			return fraction == 1 ? (jdn + 1, 0) : (jdn, fraction)
		}
	}
}

extension JulianDate {
	public func adding(days: Int) throws(JulianDateError) -> JulianDate {
		let (day, overflow) = self.jdn.addingReportingOverflow(days)
		guard !overflow else { throw .dateOutOfRange }
		return JulianDate(uncheckedJDN: day, fraction: fraction)
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
		let (day, overflow) = self.jdn.addingReportingOverflow(days)
		guard !overflow else { throw .dateOutOfRange }
		return try JulianDate(jdn: day, fraction: fraction + Double(remainder) / 86_400)
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
			let days = (Double(jdn) - Double(other.jdn)) + (fraction - other.fraction)
			return (days * Self.secondsPerDay).magnitude <= toleranceSeconds
		}
		return interval.inSeconds.magnitude <= toleranceSeconds
	}
}

extension JulianDate: Comparable {
	public static func < (lhs: JulianDate, rhs: JulianDate) -> Bool {
		(lhs.jdn, lhs.fraction) < (rhs.jdn, rhs.fraction)
	}
}

extension JulianDate: CustomStringConvertible {
	public var description: String {
		if fraction == 0 {
			return "JD \(jdn)"
		} else {
			return "JD \(jdn) \(fraction < 0 ? "-" : "+") \(abs(fraction))"
		}
	}
}

extension JulianDate: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate(jdn: \(jdn), fraction: \(fraction))"
	}
}

/// Returns the difference between two `Int` values as a `Double`.
func differenceAsDouble(_ lhs: Int, _ rhs: Int) -> Double {
	let (difference, overflow) = lhs.subtractingReportingOverflow(rhs)
	return overflow ? Double(lhs) - Double(rhs) : Double(difference)
}
