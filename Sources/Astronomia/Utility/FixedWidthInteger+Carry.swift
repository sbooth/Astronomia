//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension FixedWidthInteger {
	/// Returns `self + x + carry`, or `nil` if the result is not representable as `Self`.
	func adding(_ x: Self, carry: Self) -> Self? {
		let (y, yOverflow) = addingReportingOverflow(carry)
		if !yOverflow {
			let (sum, overflow) = y.addingReportingOverflow(x)
			return overflow ? nil : sum
		}
		let (z, zOverflow) = x.addingReportingOverflow(carry)
		guard !zOverflow else { return nil }
		let (sum, overflow) = addingReportingOverflow(z)
		return overflow ? nil : sum
	}

	/// Returns `self - x + carry`, or `nil` if the result is not representable as `Self`.
	func subtracting(_ x: Self, carry: Self) -> Self? {
		let (y, yOverflow) = addingReportingOverflow(carry)
		if !yOverflow {
			let (difference, overflow) = y.subtractingReportingOverflow(x)
			return overflow ? nil : difference
		}
		let (z, zOverflow) = x.subtractingReportingOverflow(carry)
		guard !zOverflow else { return nil }
		let (difference, overflow) = subtractingReportingOverflow(z)
		return overflow ? nil : difference
	}
}
