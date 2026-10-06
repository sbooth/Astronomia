//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension BinaryFloatingPoint {
	/// The value split into its integer floor and non-negative fractional part.
	///
	/// The result satisfies `Self(floor) + fraction == self` (subject to floating-point rounding),
	/// with `fraction` always in the right-open interval [0, 1). Unlike truncation, the floor
	/// rounds toward negative infinity, so negative values produce a positive fraction:
	///
	/// ```swift
	/// (3.75).floorAndFraction   // (floor: 3, fraction: 0.75)
	/// (-3.75).floorAndFraction  // (floor: -4, fraction: 0.25)
	/// (5.0).floorAndFraction    // (floor: 5, fraction: 0.0)
	/// ```
	///
	/// For very small negative values, computing `self - floor` can round up to exactly 1. For
	/// example, `-1e-20 - (-1.0)` evaluates to 1. In that case the fraction is normalized to 0
	/// and the floor is incremented, so `fraction` never equals 1.
	///
	/// - Returns: A tuple of the floor as an `Int` and the fractional remainder, or `nil`
	///   if the floor can't be represented exactly as an `Int`. This happens when the value is NaN,
	///   infinite, or outside the range of `Int`.
	var floorAndFraction: (floor: Int, fraction: Self)? {
		var floor = rounded(.down)
		var fraction = self - floor
		if fraction == 1 {
			fraction = 0
			floor += 1
		}
		guard let i = Int(exactly: floor) else {
			return nil
		}
		return (i, fraction)
	}
}
