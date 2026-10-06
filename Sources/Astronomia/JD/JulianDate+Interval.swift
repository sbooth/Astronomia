//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// A signed interval between two Julian Dates, stored as an integral number of days plus a
	/// fraction of a day.
	///
	/// Like ``JulianDate``, an interval may be created from any two-part split but is always stored
	/// in canonical form: `days` is integral and `fraction` lies in the right-open interval
	/// [-0.5, 0.5). The resolution is therefore at most 2^-54 days (~5 ps) regardless
	/// of the interval's length.
	///
	/// Subtracting two dates, adding an interval to a date, or adding or subtracting two intervals
	/// rounds by at most 2^-54 days. Scaling rounds by at most 3 × 2^-54 days (~14 ps) for any factor.
	/// These bounds hold while the whole days involved stay below 2^53 in magnitude.
	///
	/// Adding or subtracting intervals fails only by overflowing `Double`, at magnitudes near
	/// 10^308 days; scaling also fails for a non-finite factor. The operators trap in those cases,
	/// while ``addingChecked(_:)``, ``subtractingChecked(_:)``, and ``multipliedChecked(by:)``
	/// return `nil` instead.
	public struct Interval: Sendable, Hashable {
		/// The integral number of whole days.
		public let days: Double
		/// The fraction of a day, in the right-open interval [-0.5, 0.5).
		public let fraction: Double

		/// Creates an interval from parts that are already canonical.
		init(uncheckedDays days: Double, fraction: Double) {
			assert(days.isFinite && days == days.rounded(), "Days must be finite and integral")
			assert(fraction >= -0.5 && fraction < 0.5, "Fraction is outside the right-open interval [-0.5, 0.5)")
			self.days = days
			self.fraction = fraction
		}
	}
}

extension JulianDate.Interval {
	/// Creates an interval of `days1 + days2` days, apportioned in any convenient way,
	/// returning `nil` if the result is not finite.
	public init?(validatingDays1 days1: Double, days2: Double = 0) {
		self.init(JulianDate.Accumulator(days1: days1, days2: days2))
	}

	/// Creates an interval of `days1 + days2` days, apportioned in any convenient way.
	///
	/// For full precision pass whole days in `days1` and the remainder in `days2`.
	/// - Precondition: Both parts are finite and the result does not overflow.
	public init(days1: Double, days2: Double = 0) {
		guard let t = Self(validatingDays1: days1, days2: days2) else {
			preconditionFailure("Interval of \(days1) + \(days2) days is not finite")
		}
		self = t
	}

	/// Creates an interval from a single number of days, returning `nil` if it is not finite.
	public init?(validatingDays days: Double) {
		self.init(validatingDays1: days)
	}

	/// Creates an interval from a single number of days.
	/// - Precondition: The number of days is finite.
	public init(days: Double) {
		self.init(days1: days)
	}

	/// Creates an interval of `seconds1 + seconds2` seconds, apportioned in any convenient way
	/// and assuming 86,400 seconds per day, returning `nil` if the result is not finite.
	public init?(validatingSeconds1 seconds1: Double, seconds2: Double = 0) {
		self.init(JulianDate.Accumulator(seconds1: seconds1, seconds2: seconds2))
	}

	/// Creates an interval of `seconds1 + seconds2` seconds, apportioned in any convenient way
	/// and assuming 86,400 seconds per day.
	///
	/// For full precision pass whole seconds in `seconds1` and the fraction
	/// of a second in `seconds2`.
	/// - Precondition: Both parts are finite and the result does not overflow.
	public init(seconds1: Double, seconds2: Double = 0) {
		guard let t = Self(validatingSeconds1: seconds1, seconds2: seconds2) else {
			preconditionFailure("Interval of \(seconds1) + \(seconds2) seconds is not finite")
		}
		self = t
	}

	/// Creates an interval from a single number of seconds, assuming 86,400 seconds per day,
	/// returning `nil` if it is not finite.
	public init?(validatingSeconds seconds: Double) {
		self.init(validatingSeconds1: seconds)
	}

	/// Creates an interval from a single number of seconds, assuming 86,400 seconds per day.
	/// - Precondition: The number of seconds is finite.
	public init(seconds: Double) {
		self.init(seconds1: seconds)
	}
}

extension JulianDate.Interval {
	/// The interval in days as a single value.
	/// - Note: Loses precision for long intervals.
	public var inDays: Double {
		days + fraction
	}

	/// The interval in seconds as a single value, assuming 86,400 seconds per day.
	/// - Note: Loses precision for long intervals.
	public var inSeconds: Double {
		// The fused multiply-add adds only the final rounding to that of the fraction's product.
		(fraction * JulianDate.secondsPerDay).addingProduct(days, JulianDate.secondsPerDay)
	}

	/// The interval as an integral number of seconds and a fraction of a second in the right-open
	/// interval [-0.5, 0.5), assuming 86,400 seconds per day.
	///
	/// The seconds are exact while the interval is below 2^53 seconds (about 285 million years);
	/// the fraction is good to about 10 ps.
	public var wholeAndFractionalSeconds: (seconds: Double, fraction: Double) {
		let s = fraction * JulianDate.secondsPerDay // |s| <= 43,200; one rounding.
		var w = s.rounded()
		var f = s - w // Exact, [-0.5, 0.5].
		if f == 0.5 {
			w += 1
			f = -0.5
		}
		return ((days * JulianDate.secondsPerDay) + w, f)
	}
}

extension JulianDate.Interval: AdditiveArithmetic {
	/// The zero interval.
	public static let zero = Self(uncheckedDays: 0, fraction: 0)

	/// Returns the sum of this interval and `other`, or `nil` if it overflows. Rounds by at most
	/// 2^-54 days.
	public func addingChecked(_ other: Self) -> Self? {
		var a = JulianDate.Accumulator()
		a.add(self)
		a.add(other)
		return Self(a)
	}

	/// Returns the difference of this interval and `other`, or `nil` if it overflows. Rounds by at
	/// most 2^-54 days.
	public func subtractingChecked(_ other: Self) -> Self? {
		var a = JulianDate.Accumulator()
		a.add(self)
		a.subtract(other)
		return Self(a)
	}

	/// The sum of two intervals. Rounds by at most 2^-54 days. See ``addingChecked(_:)``.
	/// - Precondition: The result does not overflow.
	public static func + (lhs: Self, rhs: Self) -> Self {
		guard let t = lhs.addingChecked(rhs) else {
			preconditionFailure("Interval sum \(lhs) + \(rhs) overflows")
		}
		return t
	}

	/// The difference of two intervals. Rounds by at most 2^-54 days. See
	/// ``subtractingChecked(_:)``.
	/// - Precondition: The result does not overflow.
	public static func - (lhs: Self, rhs: Self) -> Self {
		guard let t = lhs.subtractingChecked(rhs) else {
			preconditionFailure("Interval difference \(lhs) - \(rhs) overflows")
		}
		return t
	}

	/// The interval scaled by `factor`, or `nil` if the result is not finite.
	///
	/// Both products are captured exactly as a high part plus a fused multiply-add residual, so the
	/// result rounds by at most 3 × 2^-54 days for any factor, while the scaled whole days stay
	/// below 2^53.
	public func multipliedChecked(by factor: Double) -> Self? {
		var a = JulianDate.Accumulator()
		a.add(days: days, multipliedBy: factor)
		a.add(days: fraction, multipliedBy: factor)
		return Self(a)
	}

	/// The interval scaled by `factor`. See ``multipliedChecked(by:)``.
	/// - Precondition: The factor is finite and the result does not overflow.
	public static func * (lhs: Self, factor: Double) -> Self {
		guard let t = lhs.multipliedChecked(by: factor) else {
			preconditionFailure("Interval \(lhs) × \(factor) is not finite")
		}
		return t
	}

	/// The interval scaled by `factor`. See ``multipliedChecked(by:)``.
	/// - Precondition: The factor is finite and the result does not overflow.
	public static func * (factor: Double, rhs: Self) -> Self {
		rhs * factor
	}
}

extension JulianDate.Interval: Comparable {
	// Canonical form makes lexicographic order numeric: more whole days always wins, because
	// fractions span less than one day.
	public static func < (lhs: Self, rhs: Self) -> Bool {
		(lhs.days, lhs.fraction) < (rhs.days, rhs.fraction)
	}
}

extension JulianDate.Interval: CustomStringConvertible {
	public var description: String {
		if fraction == 0 {
			return "\(days) days"
		} else {
			return "\(days) \(fraction < 0 ? "-" : "+") \(abs(fraction)) days"
		}
	}
}

extension JulianDate.Interval: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate.Interval(days: \(days), fraction: \(fraction))"
	}
}

extension JulianDate.Interval: Codable {
	private enum CodingKeys: String, CodingKey {
		case days1, days2
	}

	/// Decodes an interval from any split of `days1 + days2`; `days2` defaults to 0 if absent.
	/// - throws: `DecodingError.dataCorrupted` if the result is not finite.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let days1 = try container.decode(Double.self, forKey: .days1)
		let days2 = try container.decodeIfPresent(Double.self, forKey: .days2) ?? 0
		guard let interval = JulianDate.Interval(validatingDays1: days1, days2: days2) else {
			throw DecodingError.dataCorruptedError(forKey: .days1, in: container, debugDescription: "Interval parts must be finite and their sum must not overflow (days1: \(days1), days2: \(days2))")
		}
		self = interval
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(days, forKey: .days1)
		try container.encode(fraction, forKey: .days2)
	}
}

extension JulianDate {
	/// The interval `self - other`, or `nil` if it overflows. Rounds by at most 2^-54 days.
	public func intervalIfRepresentable(since other: JulianDate) -> Interval? {
		var a = Accumulator()
		a.add(self)
		a.subtract(other)
		return Interval(a)
	}

	/// The interval `self - other`. Rounds by at most 2^-54 days.
	/// - Precondition: The interval does not overflow.
	public func interval(since other: JulianDate) -> Interval {
		guard let t = intervalIfRepresentable(since: other) else {
			preconditionFailure("Interval between \(self) and \(other) overflows")
		}
		return t
	}

	/// Returns the Julian Date offset by `interval`, or `nil` if the result is not finite. Rounds
	/// by at most 2^-54 days.
	public func addingIfRepresentable(_ interval: Interval) -> JulianDate? {
		var a = Accumulator()
		a.add(self)
		a.add(interval)
		return JulianDate(a)
	}

	/// Returns the Julian Date offset by `interval`. Rounds by at most 2^-54 days.
	/// - Precondition: The result does not overflow.
	public func adding(_ interval: Interval) -> JulianDate {
		guard let date = addingIfRepresentable(interval) else {
			preconditionFailure("Adding \(interval) to \(self) is not finite")
		}
		return date
	}

	/// Returns the Julian Date offset backward by `interval`, or `nil` if the result is not finite.
	/// Rounds by at most 2^-54 days.
	public func subtractingIfRepresentable(_ interval: Interval) -> JulianDate? {
		var a = Accumulator()
		a.add(self)
		a.subtract(interval)
		return JulianDate(a)
	}

	/// Returns the Julian Date offset backward by `interval`. Rounds by at most 2^-54 days.
	/// - Precondition: The result does not overflow.
	public func subtracting(_ interval: Interval) -> JulianDate {
		guard let date = subtractingIfRepresentable(interval) else {
			preconditionFailure("Subtracting \(interval) from \(self) is not finite")
		}
		return date
	}
}

extension JulianDate {
	/// The interval `lhs - rhs`. Rounds by at most 2^-54 days.
	/// - Precondition: The interval does not overflow.
	public static func - (lhs: JulianDate, rhs: JulianDate) -> Interval {
		lhs.interval(since: rhs)
	}

	/// Returns the Julian Date offset by an interval.
	/// - Precondition: The result does not overflow.
	public static func + (lhs: JulianDate, rhs: Interval) -> JulianDate {
		lhs.adding(rhs)
	}

	/// Returns the Julian Date offset by a negated interval.
	/// - Precondition: The result does not overflow.
	public static func - (lhs: JulianDate, rhs: Interval) -> JulianDate {
		lhs.subtracting(rhs)
	}

	/// Offsets the Julian Date by an interval.
	/// - Precondition: The result does not overflow.
	public static func += (lhs: inout JulianDate, rhs: Interval) {
		lhs = lhs + rhs
	}

	/// Offsets the Julian Date by a negated interval.
	/// - Precondition: The result does not overflow.
	public static func -= (lhs: inout JulianDate, rhs: Interval) {
		lhs = lhs - rhs
	}
}
