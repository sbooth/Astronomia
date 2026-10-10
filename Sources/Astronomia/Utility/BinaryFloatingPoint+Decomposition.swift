//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension BinaryFloatingPoint {
	/// The value split into its integer floor and non-negative fractional part.
	///
	/// The result satisfies `Self(floor) + fraction == self` (subject to floating-point
	/// rounding), with `fraction` always in the right-open interval [0, 1). Unlike truncation,
	/// the floor rounds toward negative infinity, so negative values produce a non-negative
	/// fraction:
	///
	/// ```swift
	/// (3.75).floorAndFraction   // (floor: 3, fraction: 0.75)
	/// (-3.75).floorAndFraction  // (floor: -4, fraction: 0.25)
	/// (5.0).floorAndFraction    // (floor: 5, fraction: 0.0)
	/// ```
	///
	/// For very small negative values, computing `self - floor` can round up to exactly 1.
	/// For example, `-1e-20 - (-1.0)` evaluates to 1. In that case the fraction is normalized
	/// to 0 and the floor is incremented, so `fraction` never equals 1.
	///
	/// - Returns: A tuple of the floor as an `Int` and the fractional remainder, or `nil`
	///   if the floor can't be represented exactly as an `Int`. This happens when the value
	///   is NaN, infinite, or outside the range of `Int`.
	var floorAndFraction: (floor: Int, fraction: Self)? {
		var floor = rounded(.down)
		var fraction = self - floor
		if fraction == 1 {
			fraction = 0
			floor += 1
		}
		guard let i = Int(exactly: floor) else { return nil }
		return (i, fraction)
	}

	/// The value split into its nearest integer and a remainder, or `nil` if the value
	/// is not finite or the nearest integer is not representable as an `Int`.
	///
	/// The result satisfies `self == Self(nearest) + remainder` exactly, with `remainder` in
	/// the right-open interval [-0.5, 0.5). Ties round toward positive infinity, so a
	/// remainder of 0.5 never occurs, and a remainder of negative zero is returned as positive
	/// zero.
	var nearestIntegerAndRemainder: (nearest: Int, remainder: Self)? {
		guard isFinite else { return nil }
		var rounded = rounded(.toNearestOrAwayFromZero)
		var remainder = self - rounded
		if remainder == 0.5 {
			rounded += 1
			remainder = -0.5
		}
		guard let nearest = Int(exactly: rounded) else { return nil }
		return (nearest, remainder + 0)
	}

	/// The value split into two integers whose exact sum is the value, or `nil` if the
	/// value is not finite, not integral, or too far outside the `Int` range.
	///
	/// If the value is representable as an `Int`, `base` is the value and `offset` is zero.
	/// Otherwise `base` is `Int.max` or `Int.min` and `offset` holds the rest, which extends
	/// the range to roughly -2^64 through 2^64.
	var integralParts: (base: Int, offset: Int)? {
		guard isFinite, self == rounded() else { return nil }
		if let value = Int(exactly: self) {
			return (value, 0)
		}
		let intMin = Self(Int.min)
		if self > 0 {
			guard let offsetFromMin = Int(exactly: self + intMin) else { return nil }
			let (offset, overflow) = offsetFromMin.addingReportingOverflow(1)
			return overflow ? nil : (.max, offset)
		}
		guard let offset = Int(exactly: self - intMin) else { return nil }
		return (.min, offset)
	}
}
