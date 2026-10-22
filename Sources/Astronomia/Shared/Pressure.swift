//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A pressure, stored in pascals.
///
/// A pressure can be expressed in pascals, hectopascals, which equal millibars, or inches of
/// mercury, as weather reports in the United States give it. Conversions multiply by rounded
/// constants, so a round trip such as `Pressure(inchesOfMercury: 30).inchesOfMercury` can
/// differ from the original value in the last bit.
///
/// - Note: Values are not checked. A pressure created from NaN or an infinity has that value
///   in every unit, as with `Double` arithmetic.
public struct Pressure: Hashable, Sendable {
	/// The pressure in pascals.
	public let pascals: Double

	/// Creates a pressure from pascals.
	///
	/// - Parameter pascals: The pressure in pascals.
	public init(pascals: Double) {
		self.pascals = pascals
	}
}

extension Pressure {
	/// The standard atmosphere, 101,325 Pa.
	public static let standardAtmosphere = Pressure(pascals: 101_325)

	/// Pascals per inch of mercury at 0 °C, 3,386.389.
	static let pascalsPerInchOfMercury = 3_386.389

	/// Creates a pressure from hectopascals, which equal millibars.
	///
	/// - Parameter hectopascals: The pressure in hectopascals.
	public init(hectopascals: Double) {
		self.init(pascals: hectopascals * 100)
	}

	/// Creates a pressure from inches of mercury.
	///
	/// - Parameter inchesOfMercury: The pressure in inches of mercury at 0 °C.
	public init(inchesOfMercury: Double) {
		self.init(pascals: inchesOfMercury * Self.pascalsPerInchOfMercury)
	}

	/// The pressure in hectopascals, which equal millibars.
	public var hectopascals: Double {
		pascals / 100
	}

	/// The pressure in inches of mercury at 0 °C.
	public var inchesOfMercury: Double {
		pascals / Self.pascalsPerInchOfMercury
	}
}

extension Pressure {
	/// Returns a pressure from pascals.
	///
	/// Equivalent to ``init(pascals:)``, for use where the type is known, as in
	/// `.pascals(101_325)`.
	///
	/// - Parameter pascals: The pressure in pascals.
	/// - Returns: The pressure.
	public static func pascals(_ pascals: Double) -> Pressure { Pressure(pascals: pascals) }

	/// Returns a pressure from hectopascals, which equal millibars.
	///
	/// Equivalent to ``init(hectopascals:)``, for use where the type is known, as in
	/// `.hectopascals(1013.25)`.
	///
	/// - Parameter hectopascals: The pressure in hectopascals.
	/// - Returns: The pressure.
	public static func hectopascals(_ hectopascals: Double) -> Pressure { Pressure(hectopascals: hectopascals) }

	/// Returns a pressure from inches of mercury.
	///
	/// Equivalent to ``init(inchesOfMercury:)``, for use where the type is known, as in
	/// `.inchesOfMercury(29.92)`.
	///
	/// - Parameter inchesOfMercury: The pressure in inches of mercury at 0 °C.
	/// - Returns: The pressure.
	public static func inchesOfMercury(_ inchesOfMercury: Double) -> Pressure { Pressure(inchesOfMercury: inchesOfMercury) }
}

extension Pressure: Comparable {
	/// Returns `true` if the first pressure is lower than the second.
	public static func < (lhs: Pressure, rhs: Pressure) -> Bool {
		lhs.pascals < rhs.pascals
	}
}

extension Pressure: CustomStringConvertible {
	/// A textual representation of the pressure in pascals, such as `101325.0 Pa`.
	public var description: String {
		"\(pascals) Pa"
	}
}

extension Pressure: Codable {
	/// Creates a pressure by decoding it from a single value in pascals.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: Any error thrown by `decoder`.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(pascals: try container.decode(Double.self))
	}

	/// Encodes the pressure as a single value in pascals.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(pascals)
	}
}
