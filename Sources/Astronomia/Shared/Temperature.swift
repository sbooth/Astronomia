//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A thermodynamic temperature, stored in kelvins.
///
/// A temperature can be expressed in kelvins, degrees Celsius, or degrees Fahrenheit.
/// Conversions add and multiply by constants, so a round trip such as
/// `Temperature(degreesCelsius: 10).degreesCelsius` can differ from the original value in the
/// last bits.
///
/// - Note: Values are not checked. A temperature created from NaN, an infinity, or a value
///   below absolute zero has that value.
public struct Temperature: Hashable, Sendable {
	/// The temperature in kelvins.
	public let kelvins: Double

	/// Creates a temperature from kelvins.
	///
	/// - Parameter kelvins: The temperature in kelvins.
	public init(kelvins: Double) {
		self.kelvins = kelvins
	}
}

extension Temperature {
	/// The kelvins of 0 °C.
	static let kelvinsAtZeroCelsius = 273.15

	/// Creates a temperature from degrees Celsius.
	///
	/// - Parameter degreesCelsius: The temperature in degrees Celsius.
	public init(degreesCelsius: Double) {
		self.init(kelvins: degreesCelsius + Self.kelvinsAtZeroCelsius)
	}

	/// Creates a temperature from degrees Fahrenheit.
	///
	/// - Parameter degreesFahrenheit: The temperature in degrees Fahrenheit.
	public init(degreesFahrenheit: Double) {
		self.init(degreesCelsius: (degreesFahrenheit - 32) * 5 / 9)
	}

	/// The temperature in degrees Celsius.
	public var degreesCelsius: Double {
		kelvins - Self.kelvinsAtZeroCelsius
	}

	/// The temperature in degrees Fahrenheit.
	public var degreesFahrenheit: Double {
		degreesCelsius * 9 / 5 + 32
	}
}

extension Temperature {
	/// Returns a temperature from kelvins.
	///
	/// Equivalent to ``init(kelvins:)``, for use where the type is known, as in
	/// `.kelvins(283.15)`.
	///
	/// - Parameter kelvins: The temperature in kelvins.
	/// - Returns: The temperature.
	public static func kelvins(_ kelvins: Double) -> Temperature { Temperature(kelvins: kelvins) }

	/// Returns a temperature from degrees Celsius.
	///
	/// Equivalent to ``init(degreesCelsius:)``, for use where the type is known, as in
	/// `.degreesCelsius(10)`.
	///
	/// - Parameter degreesCelsius: The temperature in degrees Celsius.
	/// - Returns: The temperature.
	public static func degreesCelsius(_ degreesCelsius: Double) -> Temperature { Temperature(degreesCelsius: degreesCelsius) }

	/// Returns a temperature from degrees Fahrenheit.
	///
	/// Equivalent to ``init(degreesFahrenheit:)``, for use where the type is known, as in
	/// `.degreesFahrenheit(50)`.
	///
	/// - Parameter degreesFahrenheit: The temperature in degrees Fahrenheit.
	/// - Returns: The temperature.
	public static func degreesFahrenheit(_ degreesFahrenheit: Double) -> Temperature { Temperature(degreesFahrenheit: degreesFahrenheit) }
}

extension Temperature: Comparable {
	/// Returns `true` if the first temperature is colder than the second.
	public static func < (lhs: Temperature, rhs: Temperature) -> Bool {
		lhs.kelvins < rhs.kelvins
	}
}

extension Temperature: CustomStringConvertible {
	/// A textual representation of the temperature in kelvins, such as `283.15 K`.
	public var description: String {
		"\(kelvins) K"
	}
}

extension Temperature: Codable {
	/// Creates a temperature by decoding it from a single value in kelvins.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: Any error thrown by `decoder`.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(kelvins: try container.decode(Double.self))
	}

	/// Encodes the temperature as a single value in kelvins.
	///
	/// - Parameter encoder: The encoder to write data to.
	/// - Throws: Any error thrown by `encoder`.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(kelvins)
	}
}
