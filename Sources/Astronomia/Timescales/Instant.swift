//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A Julian Date tagged with the timescale it is expressed in.
public struct Instant<Scale: Timescale>: Hashable, Sendable {
	/// The Julian Date in the timescale `Scale`.
	public let julianDate: JulianDate

	/// Creates an instant from a Julian Date already expressed in the timescale `Scale`.
	///
	/// - Parameter julianDate: A Julian Date in `Scale`.
	public init(_ julianDate: JulianDate) {
		self.julianDate = julianDate
	}
}

extension Instant {
	/// Returns this instant expressed in another timescale.
	///
	/// The conversion goes through ``TT``. Converting to the same timescale returns the
	/// instant unchanged.
	///
	/// - Parameters:
	///   - target: The timescale to convert to.
	///   - sourceContext: Observational data used by the source timescale conversion.
	///   - targetContext: Observational data used by the target timescale conversion.
	/// - Returns: The same instant in `target`.
	/// - Throws: A ``TimescaleConversionError`` if either step of the conversion fails.
	public func converted<Target: Timescale>(
		to target: Target.Type,
		sourceContext: Scale.Context = Scale.defaultContext,
		targetContext: Target.Context = Target.defaultContext
	) throws(TimescaleConversionError) -> Instant<Target> {
		if Scale.self == Target.self {
			return Instant<Target>(julianDate)
		}
		let tt = try Scale.toTT(julianDate, context: sourceContext)
		return Instant<Target>(try Target.fromTT(tt, context: targetContext))
	}
}

extension Instant: Comparable {
	/// Returns `true` if the first instant is earlier than the second.
	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.julianDate < rhs.julianDate
	}
}

extension Instant: CustomStringConvertible {
	/// A textual representation of the instant, such as `JD 2451545 TT`.
	public var description: String {
		"\(julianDate) \(Scale.abbreviation)"
	}
}

extension Instant: Codable {
	/// Creates an instant by decoding its Julian Date.
	///
	/// - Note: The timescale is not encoded; it is supplied by the decoded type.
	public init(from decoder: any Decoder) throws {
		self.init(try JulianDate(from: decoder))
	}

	/// Encodes the instant's Julian Date.
	public func encode(to encoder: any Encoder) throws {
		try julianDate.encode(to: encoder)
	}
}
