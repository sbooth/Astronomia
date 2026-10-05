//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A Julian Date stored as the JD of the preceding midnight plus a day fraction.
///
/// A single double near JD 2.45e6 has a resolution of ~40 µs. Storing the
/// midnight and the fraction of a day separately gives a resolution of ~10 ps.
///
/// A Julian Date may be created from any two-part split following the IAU SOFA
/// convention (the date is `jd1 + jd2`), but is always stored in canonical form:
/// `midnight` is a half-integer and `dayFraction` lies in `[0, 1)`. This is
/// SOFA's "date & time" split, its most precise. Use ``parts(_:)`` to obtain
/// another split. SOFA's recommended splits, in rough order of precision, are:
///
/// | `jd1` | `jd2` | Method | Precision |
/// | --- | --- | --- | --- |
/// | 2450123.7 | 0.0 | JD | Worst |
/// | 2451545.0 | -1421.3 | J2000 | Good |
/// | 2400000.5 | 50123.2 | MJD | Good |
/// | 2450123.5 | 0.2 | Date & time | Best |
///
/// ## Supported range
///
/// Every Julian Date lies on a day whose Julian day number `J` (the day beginning
/// at midnight `J − 0.5`) satisfies `|J| < 2^51`, roughly ±6 × 10^12 years.
/// Within this range the canonical form is exact. Every initializer and every
/// arithmetic operation enforces it: trapping APIs trap and failable APIs return
/// `nil` for results outside it.
public struct JulianDate: Sendable {
	/// The Julian Date of the midnight preceding this instant (always a half-integer).
	public let midnight: Double
	/// The fraction of a day elapsed since `midnight`, in `[0, 1)`.
	public let dayFraction: Double

	/// Creates a Julian Date equal to `jd1 + jd2`, stored in canonical form.
	/// - precondition: Both parts are finite and the resulting date is within the supported range.
	public init(jd1: Double, jd2: Double = 0) {
		precondition(jd1.isFinite && jd2.isFinite, "Julian Date parts must be finite")
		guard let date = Self(validatingJD1: jd1, jd2: jd2) else {
			preconditionFailure("Julian Date \(jd1) + \(jd2) is outside the supported range")
		}
		self = date
	}

	/// Creates a Julian Date from two parts, returning `nil` if either part is not finite or the resulting date is outside the supported range.
	public init?(validatingJD1 jd1: Double, jd2: Double = 0) {
		guard jd1.isFinite, jd2.isFinite else {
			return nil
		}
		// Exact: each part minus its nearest integer lies in [-0.5, 0.5].
		let w1 = jd1.rounded()
		let w2 = jd2.rounded()
		// One rounding; g lies in [-1, 1].
		let g = (jd1 - w1) + (jd2 - w2)
		let w3 = g.rounded()
		// The integer sum is exact whenever its true value is in range; otherwise it rounds (or overflows)
		// to a value that is also out of range, which the checked initializer rejects.
		// (g - w3) is exact and lies in [-0.5, 0.5]; adding 0.5 rounds once, into [0, 1].
		self.init(dayNumber: (w1 + w2) + w3, offset: (g - w3) + 0.5)
	}
}

extension JulianDate {
	/// The exclusive upper bound on the magnitude of the Julian day number of any Julian Date.
	static let julianDayNumberBound: Double = 0x1p51

	/// Creates a Julian Date from an integral Julian day number `J` and an `offset` in days, in `[-1, 2)`,
	/// measured from midnight `J − 0.5`, returning `nil` if the result is outside the supported range.
	///
	/// This is the only initializer that sets the stored properties, so it alone enforces the invariant.
	///
	/// `J` need not be exact when it is out of range: rounding is monotonic and the bound is representable,
	/// so any computed `J` whose true value is out of range is also out of range.
	init?(dayNumber J: Double, offset: Double) {
		assert(J == J.rounded(), "Julian day number is not integral")
		assert(offset >= -1 && offset < 2, "Offset is outside the interval [-1, 2)")
		var j = J
		var f = offset
		if f < 0 {
			j -= 1
			f += 1 // [0, 1]; may round to 1
		} else if f >= 1 {
			j += 1
			f -= 1 // Exact (Sterbenz), [0, 1)
		}
		if f == 1 {
			j += 1
			f = 0
		}
		// Also rejects ±infinity.
		guard j.magnitude < Self.julianDayNumberBound else {
			return nil
		}
		// Exact: j is an integer with |j| < 2^51.
		self.midnight = j - 0.5
		self.dayFraction = f
	}
}

extension JulianDate {
	/// JD of reference epoch J2000.0 (TT).
	static let J2000_JD: Double = 2_451_545
	/// JD of MJD zero.
	static let MJD0_JD: Double = 2_400_000.5
	/// MJD of Julian epoch J2000.0.
	static let J2000_MJD: Double = 51_544.5
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
}

extension JulianDate {
	/// Creates a Julian Date from a single value (limited to ~40 µs resolution).
	/// - precondition: The Julian Date value is finite and within the supported range.
	public init(julianDate JD: Double) {
		self.init(jd1: JD, jd2: 0)
	}

	/// Creates a Julian Date from a Modified Julian Date value.
	/// - precondition: The Modified Julian Date value is finite and the resulting date is within the supported range.
	public init(modifiedJulianDate MJD: Double) {
		self.init(jd1: Self.MJD0_JD, jd2: MJD)
	}

	/// Creates a Julian Date from a number of elapsed days since J2000.0.
	/// - precondition: The number of elapsed days is finite and the resulting date is within the supported range.
	public init(daysSinceJ2000 days: Double) {
		self.init(jd1: Self.J2000_JD, jd2: days)
	}

	/// Creates a Julian Date from a Julian epoch value, e.g. 2000.0.
	/// - precondition: The epoch value is finite and the resulting date is finite and within the supported range.
	public init(julianEpoch epoch: Double) {
		self.init(jd1: Self.MJD0_JD, jd2: Self.J2000_MJD + (epoch - 2000.0) * Self.daysPerJulianYear)
	}

	/// Creates a Julian Date from a Besselian epoch value, e.g. 1950.0.
	/// - precondition: The epoch value is finite and the resulting date is finite and within the supported range.
	public init(besselianEpoch epoch: Double) {
		self.init(jd1: Self.MJD0_JD, jd2: Self.B1900_MJD + (epoch - 1900.0) * Self.daysPerTropicalYear)
	}
}

extension JulianDate {
	/// J2000.0 (2000-01-01T12:00:00).
	public static let J2000 = JulianDate(daysSinceJ2000: 0)
}

extension JulianDate {
	/// The Julian Date collapsed to a single value (loses precision).
	public var julianDate: Double {
		midnight + dayFraction
	}

	/// The Modified Julian Date (MJD).
	public var modifiedJulianDate: Double {
		(midnight - Self.MJD0_JD) + dayFraction
	}

	/// Days elapsed since J2000.0.
	public var daysSinceJ2000: Double {
		(midnight - Self.J2000_JD) + dayFraction
	}

	/// Julian centuries since J2000.0.
	public var julianCenturiesSinceJ2000: Double {
		daysSinceJ2000 / Self.daysPerJulianCentury
	}

	/// Julian epoch.
	public var julianEpoch: Double {
		2000.0 + daysSinceJ2000 / Self.daysPerJulianYear
	}

	/// Besselian epoch.
	public var besselianEpoch: Double {
		1900.0 + ((midnight - Self.J2000_JD) + (dayFraction + Self.daysFromB1900ToJ2000)) / Self.daysPerTropicalYear
	}
}

extension JulianDate {
	/// The SOFA-recommended ways of dividing a Julian Date between two doubles.
	public enum SplitMethod: Sendable {
		/// `jd1` holds the whole JD, `jd2` is zero.
		case julianDate
		/// `jd1` is J2000.0 (2451545.0), `jd2` is days since J2000.0.
		case j2000
		/// `jd1` is MJD zero (2400000.5), `jd2` is the MJD.
		case mjd
		/// `jd1` is the JD of the preceding midnight, `jd2` is the day fraction in `[0, 1)`.
		case dateAndTime
	}

	/// Returns the parts of this Julian Date divided using the specified split method.
	public func parts(_ method: SplitMethod) -> (jd1: Double, jd2: Double) {
		switch method {
		case .julianDate:
			return (midnight + dayFraction, 0)
		case .j2000:
			return (Self.J2000_JD, (midnight - Self.J2000_JD) + dayFraction)
		case .mjd:
			return (Self.MJD0_JD, (midnight - Self.MJD0_JD) + dayFraction)
		case .dateAndTime:
			return (midnight, dayFraction)
		}
	}
}

extension JulianDate {
	/// Splits a number of seconds into whole days and a fractional-day offset in `[-0.5, 0.5]`, assuming 86,400 seconds per day.
	///
	/// `days` is always integral. It is exact whenever its magnitude is less than 2^52, which covers the supported range.
	static func split(seconds: Double) -> (days: Double, offset: Double) {
		assert(seconds.isFinite, "Number of seconds must be finite")
		let r = seconds.remainder(dividingBy: secondsPerDay) // exact, |r| ≤ 43200
															 // (seconds - r) is a multiple of 86,400 but can round for |seconds| ≥ 2^60;
															 // rounding the quotient recovers the exact whole-day count.
		let d = ((seconds - r) / secondsPerDay).rounded()
		return (d, r / secondsPerDay)
	}
}

extension JulianDate {
	/// Returns the Julian Date offset by a number of days.
	/// - precondition: The number of days is finite and the resulting date is within the supported range.
	public func adding(days: Double) -> JulianDate {
		precondition(days.isFinite, "Number of days must be finite")
		let wholeDays = days.rounded()
		// (midnight + 0.5) is exact. (days - wholeDays) is exact and lies in [-0.5, 0.5], so the offset lies in [-0.5, 1.5].
		guard let date = JulianDate(dayNumber: (midnight + 0.5) + wholeDays, offset: dayFraction + (days - wholeDays)) else {
			preconditionFailure("Adding \(days) days to \(self) leaves the supported range")
		}
		return date
	}

	/// Returns the date offset by a number of seconds, assuming 86,400 seconds per day.
	/// - precondition: The number of seconds is finite and the resulting date is within the supported range.
	public func adding(seconds: Double) -> JulianDate {
		precondition(seconds.isFinite, "Number of seconds must be finite")
		let (d, offset) = Self.split(seconds: seconds)
		guard let date = JulianDate(dayNumber: (midnight + 0.5) + d, offset: dayFraction + offset) else {
			preconditionFailure("Adding \(seconds) seconds to \(self) leaves the supported range")
		}
		return date
	}

	/// Returns the Julian Date offset by a number of days.
	/// - precondition: The number of days is finite and the resulting date is within the supported range.
	public static func + (lhs: JulianDate, days: Double) -> JulianDate {
		lhs.adding(days: days)
	}

	/// Returns the Julian Date offset by a number of days.
	/// - precondition: The number of days is finite and the resulting date is within the supported range.
	public static func - (lhs: JulianDate, days: Double) -> JulianDate {
		lhs.adding(days: -days)
	}

	/// The interval `lhs - rhs` in days.
	public static func - (lhs: JulianDate, rhs: JulianDate) -> Double {
		(lhs.midnight - rhs.midnight) + (lhs.dayFraction - rhs.dayFraction)
	}
}

extension JulianDate {
	/// Returns `true` if the specified Julian Date is within the specified tolerance of this Julian Date, assuming 86,400 seconds per day.
	///
	/// Use this instead of `==` when comparing dates that took different computational paths, e.g. a JD-method value against a date-and-time split.
	///
	/// This is not an equivalence relation (it is not transitive), so it is not a substitute for `==` in `Hashable` or `Set` contexts.
	///
	/// - precondition: The specified tolerance is non-negative and not NaN.
	public func isApproximatelyEqual(to other: JulianDate, toleranceSeconds: Double) -> Bool {
		precondition(toleranceSeconds >= 0, "Tolerance must be non-negative")
		let deltaSeconds = (self - other) * Self.secondsPerDay
		return deltaSeconds.magnitude <= toleranceSeconds
	}
}

// Stored parts are canonical, so equality and hashing can be synthesized.
extension JulianDate: Hashable {}

extension JulianDate: Comparable {
	public static func < (lhs: JulianDate, rhs: JulianDate) -> Bool {
		(lhs.midnight, lhs.dayFraction) < (rhs.midnight, rhs.dayFraction)
	}
}

extension JulianDate: CustomStringConvertible {
	public var description: String {
		"JulianDate(midnight: \(midnight), dayFraction: \(dayFraction))"
	}
}

extension JulianDate: Codable {
	// Keys keep SOFA naming; any split decodes correctly.
	private enum CodingKeys: String, CodingKey {
		case midnight = "jd1"
		case dayFraction = "jd2"
	}

	/// Decodes a Julian Date from any split of `jd1 + jd2`; `jd2` defaults to 0 if absent.
	/// - throws: `DecodingError.dataCorrupted` if a part is not finite or the resulting date is outside the supported range.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let jd1 = try container.decode(Double.self, forKey: .midnight)
		let jd2 = try container.decodeIfPresent(Double.self, forKey: .dayFraction) ?? 0
		guard let date = JulianDate(validatingJD1: jd1, jd2: jd2) else {
			throw DecodingError.dataCorruptedError(forKey: .midnight, in: container, debugDescription: "Julian Date parts must be finite and their sum within the supported range (jd1: \(jd1), jd2: \(jd2))")
		}
		self = date
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(midnight, forKey: .midnight)
		try container.encode(dayFraction, forKey: .dayFraction)
	}
}
