//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension BinaryFloatingPoint {
	/// The value decomposed into its floor and a fraction in `[0, 1)`.
	/// - returns: The floor and fraction, or `nil` if the value is not finite or the floor cannot be represented as an `Int`.
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
