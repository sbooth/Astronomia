//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct FloorAndFractionTests {
	private func expect(_ x: Double, floor: Int, fraction: Double, sourceLocation: SourceLocation = #_sourceLocation) {
		let result = x.floorAndFraction
		#expect(result?.floor == floor, "\(x)", sourceLocation: sourceLocation)
		#expect(result?.fraction == fraction, "\(x)", sourceLocation: sourceLocation)
	}

	@Test func values() {
		expect(2.5, floor: 2, fraction: 0.5)
		expect(-2.5, floor: -3, fraction: 0.5)
		expect(3, floor: 3, fraction: 0)
		expect(-3, floor: -3, fraction: 0)
		expect(0, floor: 0, fraction: 0)
		expect(-0.0, floor: 0, fraction: 0)
		expect(-0x1p63, floor: .min, fraction: 0)
	}

	@Test func fractionThatRoundsToOneCarries() {
		// -1e-20 - (-1) rounds to 1, so the result is carried to the next integer
		expect(-1e-20, floor: 0, fraction: 0)
		expect(-0x1p-54, floor: 0, fraction: 0)
		// -2^-53 - (-1) is exactly the largest Double below 1
		expect(-0x1p-53, floor: -1, fraction: Double(1).nextDown)
	}

	@Test func unrepresentableValues() {
		for x in [Double.nan, .infinity, -.infinity, 0x1p63, 1e300, -1e300] {
			#expect(x.floorAndFraction == nil, "\(x)")
		}
	}
}
