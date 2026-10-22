//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A length, stored in astronomical units.
///
/// A distance can be expressed in astronomical units, kilometers, meters, or micrometers. The
/// astronomical unit is the exact 149,597,870,700 m of IAU 2012 Resolution B2. Conversions
/// multiply by a rounded constant, so a round trip such as `Distance(kilometers: 1).kilometers`
/// can differ from the original value in the last bit.
///
/// A distance can be negative, as for a coordinate or a difference.
///
/// - Note: Values are not checked. A distance created from NaN or an infinity has that value
///   in every unit, as with `Double` arithmetic.
public struct Distance: Hashable, Sendable {
	/// The distance in astronomical units.
	public let astronomicalUnits: Double

	/// Creates a distance from astronomical units.
	///
	/// - Parameter astronomicalUnits: The distance in astronomical units.
	public init(astronomicalUnits: Double) {
		self.astronomicalUnits = astronomicalUnits
	}
}

extension Distance {
	/// Creates a distance from kilometers.
	///
	/// - Parameter kilometers: The distance in kilometers.
	public init(kilometers: Double) {
		self.init(astronomicalUnits: kilometers / kilometersPerAstronomicalUnit)
	}

	/// Creates a distance from meters.
	///
	/// - Parameter meters: The distance in meters.
	public init(meters: Double) {
		self.init(astronomicalUnits: meters / metersPerAstronomicalUnit)
	}

	/// Creates a distance from micrometers, as for a wavelength.
	///
	/// - Parameter micrometers: The distance in micrometers.
	public init(micrometers: Double) {
		self.init(astronomicalUnits: micrometers / micrometersPerAstronomicalUnit)
	}

	/// The distance in kilometers.
	public var kilometers: Double {
		astronomicalUnits * kilometersPerAstronomicalUnit
	}

	/// The distance in meters.
	public var meters: Double {
		astronomicalUnits * metersPerAstronomicalUnit
	}

	/// The distance in micrometers.
	public var micrometers: Double {
		astronomicalUnits * micrometersPerAstronomicalUnit
	}

	/// The absolute value of the distance.
	public var magnitude: Distance {
		Distance(astronomicalUnits: Swift.abs(astronomicalUnits))
	}
}

extension Distance {
	/// Returns a distance from astronomical units.
	///
	/// Equivalent to ``init(astronomicalUnits:)``, for use where the type is known, as in
	/// `.astronomicalUnits(5.2)`.
	///
	/// - Parameter astronomicalUnits: The distance in astronomical units.
	/// - Returns: The distance.
	public static func astronomicalUnits(_ astronomicalUnits: Double) -> Distance { Distance(astronomicalUnits: astronomicalUnits) }

	/// Returns a distance from kilometers.
	///
	/// Equivalent to ``init(kilometers:)``, for use where the type is known, as in
	/// `.kilometers(384_400)`.
	///
	/// - Parameter kilometers: The distance in kilometers.
	/// - Returns: The distance.
	public static func kilometers(_ kilometers: Double) -> Distance { Distance(kilometers: kilometers) }

	/// Returns a distance from meters.
	///
	/// Equivalent to ``init(meters:)``, for use where the type is known, as in
	/// `.meters(6_378_137)`.
	///
	/// - Parameter meters: The distance in meters.
	/// - Returns: The distance.
	public static func meters(_ meters: Double) -> Distance { Distance(meters: meters) }

	/// Returns a distance from micrometers.
	///
	/// Equivalent to ``init(micrometers:)``, for use where the type is known, as in
	/// `.micrometers(0.55)`.
	///
	/// - Parameter micrometers: The distance in micrometers.
	/// - Returns: The distance.
	public static func micrometers(_ micrometers: Double) -> Distance { Distance(micrometers: micrometers) }
}

extension Distance: AdditiveArithmetic {
	/// The zero distance.
	public static let zero = Distance(astronomicalUnits: 0)

	public static func + (lhs: Distance, rhs: Distance) -> Distance {
		Distance(astronomicalUnits: lhs.astronomicalUnits + rhs.astronomicalUnits)
	}

	public static func - (lhs: Distance, rhs: Distance) -> Distance {
		Distance(astronomicalUnits: lhs.astronomicalUnits - rhs.astronomicalUnits)
	}
}

extension Distance {
	/// Returns the distance with its sign reversed.
	public static prefix func - (operand: Distance) -> Distance {
		Distance(astronomicalUnits: -operand.astronomicalUnits)
	}
}

extension Distance {
	/// Returns the distance scaled by a factor.
	public static func * (lhs: Distance, rhs: Double) -> Distance {
		Distance(astronomicalUnits: lhs.astronomicalUnits * rhs)
	}

	/// Returns the distance scaled by a factor.
	public static func * (lhs: Double, rhs: Distance) -> Distance {
		Distance(astronomicalUnits: lhs * rhs.astronomicalUnits)
	}

	/// Returns the distance divided by a divisor.
	public static func / (lhs: Distance, rhs: Double) -> Distance {
		Distance(astronomicalUnits: lhs.astronomicalUnits / rhs)
	}

	/// Returns the ratio of two distances.
	public static func / (lhs: Distance, rhs: Distance) -> Double {
		lhs.astronomicalUnits / rhs.astronomicalUnits
	}

	/// Scales the distance by a factor.
	public static func *= (lhs: inout Distance, rhs: Double) {
		lhs = lhs * rhs
	}

	/// Divides the distance by a divisor.
	public static func /= (lhs: inout Distance, rhs: Double) {
		lhs = lhs / rhs
	}
}

extension Distance: Comparable {
	/// Returns `true` if the first distance is smaller than the second.
	public static func < (lhs: Distance, rhs: Distance) -> Bool {
		lhs.astronomicalUnits < rhs.astronomicalUnits
	}
}

extension Distance: CustomStringConvertible {
	/// A textual representation of the distance in astronomical units, such as `1.0 au`.
	public var description: String {
		"\(astronomicalUnits) au"
	}
}

extension Distance: Codable {
	/// Creates a distance by decoding it from a single value in astronomical units.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: Any error thrown by `decoder`.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(astronomicalUnits: try container.decode(Double.self))
	}

	/// Encodes the distance as a single value in astronomical units.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(astronomicalUnits)
	}
}
