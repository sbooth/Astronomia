//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A rate of change of distance, stored in astronomical units per day.
///
/// A speed can be expressed in astronomical units per day, kilometers per second, or meters per
/// second. Conversions multiply by rounded constants, so a round trip such as
/// `Speed(kilometersPerSecond: 1).kilometersPerSecond` can differ from the original value in
/// the last bit.
///
/// A speed can be negative, as for a radial velocity of approach.
///
/// - Note: Values are not checked. A speed created from NaN or an infinity has that value in
///   every unit, as with `Double` arithmetic.
public struct Speed: Hashable, Sendable {
	/// The speed in astronomical units per day.
	public let astronomicalUnitsPerDay: Double

	/// Creates a speed from astronomical units per day.
	///
	/// - Parameter astronomicalUnitsPerDay: The speed in astronomical units per day.
	public init(astronomicalUnitsPerDay: Double) {
		self.astronomicalUnitsPerDay = astronomicalUnitsPerDay
	}
}

extension Speed {
	/// Creates a speed from kilometers per second.
	///
	/// - Parameter kilometersPerSecond: The speed in kilometers per second.
	public init(kilometersPerSecond: Double) {
		self.init(astronomicalUnitsPerDay: kilometersPerSecond * (secondsPerDay / kilometersPerAstronomicalUnit))
	}

	/// Creates a speed from meters per second.
	///
	/// - Parameter metersPerSecond: The speed in meters per second.
	public init(metersPerSecond: Double) {
		self.init(astronomicalUnitsPerDay: metersPerSecond * (secondsPerDay / metersPerAstronomicalUnit))
	}

	/// The speed in kilometers per second.
	public var kilometersPerSecond: Double {
		astronomicalUnitsPerDay * (kilometersPerAstronomicalUnit / secondsPerDay)
	}

	/// The speed in meters per second.
	public var metersPerSecond: Double {
		astronomicalUnitsPerDay * (metersPerAstronomicalUnit / secondsPerDay)
	}

	/// The absolute value of the speed.
	public var magnitude: Speed {
		Speed(astronomicalUnitsPerDay: Swift.abs(astronomicalUnitsPerDay))
	}
}

extension Speed {
	/// Returns a speed from astronomical units per day.
	///
	/// Equivalent to ``init(astronomicalUnitsPerDay:)``, for use where the type is known, as
	/// in `.astronomicalUnitsPerDay(0.017)`.
	///
	/// - Parameter astronomicalUnitsPerDay: The speed in astronomical units per day.
	/// - Returns: The speed.
	public static func astronomicalUnitsPerDay(_ astronomicalUnitsPerDay: Double) -> Speed { Speed(astronomicalUnitsPerDay: astronomicalUnitsPerDay) }

	/// Returns a speed from kilometers per second.
	///
	/// Equivalent to ``init(kilometersPerSecond:)``, for use where the type is known, as in
	/// `.kilometersPerSecond(-110.5)`.
	///
	/// - Parameter kilometersPerSecond: The speed in kilometers per second.
	/// - Returns: The speed.
	public static func kilometersPerSecond(_ kilometersPerSecond: Double) -> Speed { Speed(kilometersPerSecond: kilometersPerSecond) }

	/// Returns a speed from meters per second.
	///
	/// Equivalent to ``init(metersPerSecond:)``, for use where the type is known, as in
	/// `.metersPerSecond(465)`.
	///
	/// - Parameter metersPerSecond: The speed in meters per second.
	/// - Returns: The speed.
	public static func metersPerSecond(_ metersPerSecond: Double) -> Speed { Speed(metersPerSecond: metersPerSecond) }
}

extension Speed: AdditiveArithmetic {
	/// The zero speed.
	public static let zero = Speed(astronomicalUnitsPerDay: 0)

	public static func + (lhs: Speed, rhs: Speed) -> Speed {
		Speed(astronomicalUnitsPerDay: lhs.astronomicalUnitsPerDay + rhs.astronomicalUnitsPerDay)
	}

	public static func - (lhs: Speed, rhs: Speed) -> Speed {
		Speed(astronomicalUnitsPerDay: lhs.astronomicalUnitsPerDay - rhs.astronomicalUnitsPerDay)
	}
}

extension Speed {
	/// Returns the speed with its sign reversed.
	public static prefix func - (operand: Speed) -> Speed {
		Speed(astronomicalUnitsPerDay: -operand.astronomicalUnitsPerDay)
	}
}

extension Speed {
	/// Returns the speed scaled by a factor.
	public static func * (lhs: Speed, rhs: Double) -> Speed {
		Speed(astronomicalUnitsPerDay: lhs.astronomicalUnitsPerDay * rhs)
	}

	/// Returns the speed scaled by a factor.
	public static func * (lhs: Double, rhs: Speed) -> Speed {
		Speed(astronomicalUnitsPerDay: lhs * rhs.astronomicalUnitsPerDay)
	}

	/// Returns the speed divided by a divisor.
	public static func / (lhs: Speed, rhs: Double) -> Speed {
		Speed(astronomicalUnitsPerDay: lhs.astronomicalUnitsPerDay / rhs)
	}

	/// Returns the ratio of two speeds.
	public static func / (lhs: Speed, rhs: Speed) -> Double {
		lhs.astronomicalUnitsPerDay / rhs.astronomicalUnitsPerDay
	}

	/// Scales the speed by a factor.
	public static func *= (lhs: inout Speed, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the speed by a divisor.
	public static func /= (lhs: inout Speed, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension Speed: Comparable {
	/// Returns `true` if the first speed is smaller than the second.
	public static func < (lhs: Speed, rhs: Speed) -> Bool {
		lhs.astronomicalUnitsPerDay < rhs.astronomicalUnitsPerDay
	}
}

extension Speed: CustomStringConvertible {
	/// A textual representation of the speed in astronomical units per day, such as
	/// `0.017 au/d`.
	public var description: String {
		"\(astronomicalUnitsPerDay) au/d"
	}
}

extension Speed: Codable {
	/// Creates a speed by decoding it from a single value in astronomical units per day.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: Any error thrown by `decoder`.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(astronomicalUnitsPerDay: try container.decode(Double.self))
	}

	/// Encodes the speed as a single value in astronomical units per day.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(astronomicalUnitsPerDay)
	}
}
