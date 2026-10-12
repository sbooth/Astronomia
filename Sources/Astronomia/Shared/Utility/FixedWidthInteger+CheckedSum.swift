//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension FixedWidthInteger {
	/// Returns `self + x + y`, or `nil` if the result is not representable as `Self`.
	///
	/// Only the result has to be representable; an intermediate sum may overflow.
	///
	/// - Parameters:
	///   - x: The first value to add.
	///   - y: The second value to add.
	/// - Returns: `self + x + y`, or `nil` if the result is not representable as `Self`.
	func adding(_ x: Self, plus y: Self) -> Self? {
		let (a, aOverflow) = addingReportingOverflow(y)
		if !aOverflow {
			let (sum, overflow) = a.addingReportingOverflow(x)
			return overflow ? nil : sum
		}
		let (b, bOverflow) = x.addingReportingOverflow(y)
		guard !bOverflow else { return nil }
		let (sum, overflow) = addingReportingOverflow(b)
		return overflow ? nil : sum
	}

	/// Returns `self - x + y`, or `nil` if the result is not representable as `Self`.
	///
	/// Only the result has to be representable; an intermediate difference may overflow.
	///
	/// - Parameters:
	///   - x: The value to subtract.
	///   - y: The value to add.
	/// - Returns: `self - x + y`, or `nil` if the result is not representable as `Self`.
	func subtracting(_ x: Self, plus y: Self) -> Self? {
		let (a, aOverflow) = addingReportingOverflow(y)
		if !aOverflow {
			let (difference, overflow) = a.subtractingReportingOverflow(x)
			return overflow ? nil : difference
		}
		if x >= y {
			let (b, bOverflow) = x.subtractingReportingOverflow(y)
			guard !bOverflow else { return nil }
			let (difference, overflow) = subtractingReportingOverflow(b)
			return overflow ? nil : difference
		} else {
			let (b, bOverflow) = y.subtractingReportingOverflow(x)
			guard !bOverflow else { return nil }
			let (sum, overflow) = addingReportingOverflow(b)
			return overflow ? nil : sum
		}
	}
}
