//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct TwoSumTests {
	@Test func exactSums() throws {
		let small = try #require(twoSum(1, 1e-20))
		#expect(small.sum == 1)
		#expect(small.error == 1e-20)

		let tenths = try #require(twoSum(0.1, 0.2))
		#expect(tenths.sum == 0.30000000000000004)
		#expect(tenths.error == -2.7755575615628914e-17)

		let exact = try #require(twoSum(0.5, 0.25))
		#expect(exact.sum == 0.75)
		#expect(exact.error == 0)

		let cancelled = try #require(twoSum(1e300, -1e300))
		#expect(cancelled.sum == 0)
		#expect(cancelled.error == 0)
	}

	@Test func overflow() {
		#expect(twoSum(.greatestFiniteMagnitude, .greatestFiniteMagnitude) == nil)
		#expect(twoSum(-.greatestFiniteMagnitude, -.greatestFiniteMagnitude) == nil)
		#expect(twoSum(.infinity, 0) == nil)
		#expect(twoSum(.nan, 0) == nil)
	}
}
