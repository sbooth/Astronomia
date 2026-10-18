//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A length, stored in astronomical units.
///
/// A distance can be expressed in astronomical units, kilometers, or meters. The astronomical
/// unit is the exact 149,597,870,700 m of IAU 2012 Resolution B2. Conversions multiply by a
/// rounded constant, so a round trip such as `Distance(kilometers: 1).kilometers` can differ
/// from the original value in the last bit.
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
	/// Meters per astronomical unit, exact (IAU 2012 Resolution B2).
	static let metersPerAstronomicalUnit: Double = 149_597_870_700
	/// Kilometers per astronomical unit, 149,597,870.7, rounded to a `Double`.
	static let kilometersPerAstronomicalUnit: Double = 149_597_870.7

	/// Creates a distance from kilometers.
	///
	/// - Parameter kilometers: The distance in kilometers.
	public init(kilometers: Double) {
		self.init(astronomicalUnits: kilometers / Self.kilometersPerAstronomicalUnit)
	}

	/// Creates a distance from meters.
	///
	/// - Parameter meters: The distance in meters.
	public init(meters: Double) {
		self.init(astronomicalUnits: meters / Self.metersPerAstronomicalUnit)
	}

	/// The distance in kilometers.
	public var kilometers: Double {
		astronomicalUnits * Self.kilometersPerAstronomicalUnit
	}

	/// The distance in meters.
	public var meters: Double {
		astronomicalUnits * Self.metersPerAstronomicalUnit
	}

	/// The absolute value of the distance.
	public var magnitude: Distance {
		Distance(astronomicalUnits: Swift.abs(astronomicalUnits))
	}
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
