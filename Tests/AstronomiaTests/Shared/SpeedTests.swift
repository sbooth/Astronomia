//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct SpeedTests {
	@Test func units() {
		// 1 au/d is 149,597,870.7 km over 86,400 s.
		let auPerDay = Speed(astronomicalUnitsPerDay: 1)
		#expect(abs(auPerDay.kilometersPerSecond - 1_731.456_836_805_555_6) <= 1e-12)
		#expect(abs(auPerDay.metersPerSecond - 1_731_456.836_805_555_6) <= 1e-9)
		#expect(abs(Speed(kilometersPerSecond: 1_731.456_836_805_555_6).astronomicalUnitsPerDay - 1) <= 1e-15)
		#expect(abs(Speed(metersPerSecond: 1_000).kilometersPerSecond - 1) <= 1e-15)
		#expect(abs(Speed(kilometersPerSecond: 1).kilometersPerSecond - 1) <= 1e-15)
		// The speed of light
		#expect(abs(Speed(kilometersPerSecond: speedOfLight).astronomicalUnitsPerDay - speedOfLightAstronomicalUnitsPerDay) <= 1e-12)
	}

	@Test func matchesVelocity() {
		let speed = Speed(kilometersPerSecond: -110.51)
		let velocity = Velocity<ICRS>(kilometersPerSecond: SIMD3(-110.51, 0, 0))
		#expect(speed.astronomicalUnitsPerDay == velocity.astronomicalUnitsPerDay.x)
		#expect(speed.kilometersPerSecond == velocity.kilometersPerSecond.x)
	}

	@Test func arithmetic() {
		let a = Speed(astronomicalUnitsPerDay: 1.5)
		let b = Speed(astronomicalUnitsPerDay: 0.5)
		#expect(a + b == Speed(astronomicalUnitsPerDay: 2))
		#expect(a - b == Speed(astronomicalUnitsPerDay: 1))
		#expect(-a == Speed(astronomicalUnitsPerDay: -1.5))
		#expect(a * 2 == Speed(astronomicalUnitsPerDay: 3))
		#expect(2 * a == Speed(astronomicalUnitsPerDay: 3))
		#expect(a / 3 == Speed(astronomicalUnitsPerDay: 0.5))
		#expect(a / b == 3)
		#expect((-a).magnitude == a)
		#expect(b < a)
		#expect(Speed.zero == Speed(astronomicalUnitsPerDay: 0))

		var c = a
		c *= 2
		c /= 4
		#expect(c == Speed(astronomicalUnitsPerDay: 0.75))
	}

	@Test func description() {
		#expect(Speed(astronomicalUnitsPerDay: 1).description == "1.0 au/d")
	}

	@Test(arguments: [0.0, -0.0, 1, -110.51, 299_792.458, 1e-9, 1e20, .infinity])
	func factoriesMatchInitializers(value: Double) {
		// Each static method is the initializer of the same unit, bit for bit.
		#expect(Speed.astronomicalUnitsPerDay(value).astronomicalUnitsPerDay.bitPattern == Speed(astronomicalUnitsPerDay: value).astronomicalUnitsPerDay.bitPattern)
		#expect(Speed.kilometersPerSecond(value).astronomicalUnitsPerDay.bitPattern == Speed(kilometersPerSecond: value).astronomicalUnitsPerDay.bitPattern)
		#expect(Speed.metersPerSecond(value).astronomicalUnitsPerDay.bitPattern == Speed(metersPerSecond: value).astronomicalUnitsPerDay.bitPattern)
	}

	@Test func nanPropagates() {
		#expect(Speed.kilometersPerSecond(.nan).astronomicalUnitsPerDay.isNaN)
		#expect(Speed.metersPerSecond(.nan).astronomicalUnitsPerDay.isNaN)
	}
}

#if canImport(Foundation)

import Foundation

@Suite struct SpeedCodableTests {
	@Test func codable() throws {
		let speed = Speed(astronomicalUnitsPerDay: 0.017)
		let data = try JSONEncoder().encode(speed)
		#expect(String(decoding: data, as: UTF8.self) == "0.017")
		#expect(try JSONDecoder().decode(Speed.self, from: data) == speed)
	}
}

#endif
