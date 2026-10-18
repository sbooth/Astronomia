//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Comparable {
	/// Returns this value limited to the bounds of the given range.
	///
	/// ```swift
	/// 42.clamped(to: 0...100)    // 42
	/// (-5).clamped(to: 0...100)  // 0
	/// 130.clamped(to: 0...100)   // 100
	/// ```
	///
	/// - Parameter range: The range to clamp this value to.
	/// - Returns: This value if it lies within `range`; otherwise, the nearest bound of `range`.
	func clamped(to range: ClosedRange<Self>) -> Self {
		Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
	}
}
