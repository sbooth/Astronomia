//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A source of ΔT = TT - UT1.
///
/// ``EarthOrientationTable``, ``DeltaTTable``, and ``DeltaTModel`` are sources. Combine
/// sources with ``DeltaTSourceList``, or supply a function or a constant with
/// ``DeltaTFunction``.
public protocol DeltaTSource: Sendable {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: ΔT, in seconds, or `nil` if the source does not cover `tt`.
	func deltaT(at tt: JulianDate) -> Double?
}

/// A source of ΔT that tries a list of sources in order.
///
/// ΔT comes from the first source that covers the date. Sources can differ where one hands
/// over to the next, so ΔT need not be continuous there.
public struct DeltaTSourceList: DeltaTSource {
	/// The sources, in order of preference.
	public var sources: [any DeltaTSource]

	/// Creates a list of sources.
	///
	/// - Parameter sources: The sources, in order of preference.
	public init(_ sources: [any DeltaTSource]) {
		self.sources = sources
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		for source in sources {
			if let deltaT = source.deltaT(at: tt) {
				return deltaT
			}
		}
		return nil
	}
}

/// A source of ΔT given by a function.
///
/// ```swift
/// // ΔT fixed at 69.2 s, as stated for a published prediction
/// let context = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
/// ```
public struct DeltaTFunction: DeltaTSource {
	/// The function, returning ΔT in seconds at a TT, or `nil` where it does not apply.
	let function: @Sendable (JulianDate) -> Double?

	/// Creates a source from a function.
	///
	/// - Parameter function: A function returning ΔT, in seconds, at a Julian Date in TT, or
	///   `nil` for dates it does not cover.
	public init(_ function: @escaping @Sendable (JulianDate) -> Double?) {
		self.function = function
	}

	/// Returns a source with the same ΔT at every date.
	///
	/// - Parameter seconds: ΔT, in seconds.
	public static func constant(_ seconds: Double) -> DeltaTFunction {
		DeltaTFunction { _ in seconds }
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		function(tt)
	}
}
