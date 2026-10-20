//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct DistanceTests {
	@Test func units() {
		let au = Distance(astronomicalUnits: 1)
		#expect(au.meters == 149_597_870_700)
		#expect(au.kilometers == 149_597_870.7)
		#expect(Distance(meters: 149_597_870_700).astronomicalUnits == 1)
		#expect(abs(Distance(kilometers: 384_400).astronomicalUnits - 0.002_569_555_289_799_990_7) <= 1e-18)
		#expect(abs(Distance(kilometers: 1).kilometers - 1) <= 1e-15)
	}

	@Test func arithmetic() {
		let a = Distance(astronomicalUnits: 1.5)
		let b = Distance(astronomicalUnits: 0.5)
		#expect(a + b == Distance(astronomicalUnits: 2))
		#expect(a - b == Distance(astronomicalUnits: 1))
		#expect(-a == Distance(astronomicalUnits: -1.5))
		#expect(a * 2 == Distance(astronomicalUnits: 3))
		#expect(2 * a == Distance(astronomicalUnits: 3))
		#expect(a / 3 == Distance(astronomicalUnits: 0.5))
		#expect(a / b == 3)
		#expect((-a).magnitude == a)
		#expect(b < a)
		#expect(Distance.zero == Distance(astronomicalUnits: 0))

		var c = a
		c *= 2
		c /= 4
		#expect(c == Distance(astronomicalUnits: 0.75))
	}

	@Test func description() {
		#expect(Distance(astronomicalUnits: 1).description == "1.0 au")
	}
}

#if canImport(Foundation)

import Foundation

@Suite struct DistanceCodableTests {
	@Test func codable() throws {
		let distance = Distance(astronomicalUnits: 5.2)
		let data = try JSONEncoder().encode(distance)
		#expect(String(decoding: data, as: UTF8.self) == "5.2")
		#expect(try JSONDecoder().decode(Distance.self, from: data) == distance)
	}
}

#endif

@Suite struct DistanceFactoryTests {
	@Test(arguments: [0.0, -0.0, 1, -2.5, 384_400, 6_378_137, 1e-9, 1e20, .infinity])
	func factoriesMatchInitializers(value: Double) {
		// Each static method is the initializer of the same unit, bit for bit.
		#expect(Distance.astronomicalUnits(value).astronomicalUnits.bitPattern == Distance(astronomicalUnits: value).astronomicalUnits.bitPattern)
		#expect(Distance.kilometers(value).astronomicalUnits.bitPattern == Distance(kilometers: value).astronomicalUnits.bitPattern)
		#expect(Distance.meters(value).astronomicalUnits.bitPattern == Distance(meters: value).astronomicalUnits.bitPattern)
	}

	@Test func nanPropagates() {
		#expect(Distance.kilometers(.nan).astronomicalUnits.isNaN)
		#expect(Distance.meters(.nan).astronomicalUnits.isNaN)
	}

	@Test func usableWhereTheTypeIsKnown() {
		// The leading-dot form works wherever a Distance is expected.
		let au: Distance = .astronomicalUnits(1)
		#expect(au.meters == 149_597_870_700)
		#expect(Distance(kilometers: 149_597_870.7) == .astronomicalUnits(1))
		#expect(.kilometers(1) + .meters(500) == Distance(kilometers: 1) + Distance(meters: 500))
		#expect(Distance.meters(1) < .kilometers(1))
		#expect([Distance.kilometers(10), .meters(5), .astronomicalUnits(1)].max() == .astronomicalUnits(1))
		let p = Position<ICRS>(x: .astronomicalUnits(1), y: .kilometers(384_400), z: .zero)
		#expect(p.y == Distance(kilometers: 384_400))
	}
}
