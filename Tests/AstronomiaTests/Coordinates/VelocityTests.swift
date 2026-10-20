//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct VelocityTests {
	@Test func units() {
		let v = Velocity<ICRS>(kilometersPerSecond: SIMD3(29.78, 0, -1))
		let auPerDay = v.astronomicalUnitsPerDay
		#expect(abs(auPerDay.x - 29.78 * 86_400 / 149_597_870.7) <= 1e-17)
		#expect(auPerDay.y == 0)
		let back = v.kilometersPerSecond
		#expect(abs(back.x - 29.78) <= 1e-14 && back.y == 0 && abs(back.z + 1) <= 1e-15)
		#expect(Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(1, 2, 3)).astronomicalUnitsPerDay == SIMD3(1, 2, 3))
		#expect(Velocity<ICRS>.zero.astronomicalUnitsPerDay == .zero)
	}

	@Test func arithmetic() {
		let a = Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(1, 2, 3))
		let b = Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(0.5, -1, 0))
		#expect((a + b).astronomicalUnitsPerDay == SIMD3(1.5, 1, 3))
		#expect((a - b).astronomicalUnitsPerDay == SIMD3(0.5, 3, 3))
		#expect((-a).astronomicalUnitsPerDay == SIMD3(-1, -2, -3))
		#expect((a * 2).astronomicalUnitsPerDay == SIMD3(2, 4, 6))
		#expect((2 * a) == a * 2)
		let displacement = a.displacement(overDays: -2)
		#expect(displacement == Position<ICRS>(x: .astronomicalUnits(-2), y: .astronomicalUnits(-4), z: .astronomicalUnits(-6)))
	}

	@Test func conversion() {
		let v = Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(0.3, -0.8, 0.5))
		let p = Position<ICRS>(x: .astronomicalUnits(0.3), y: .astronomicalUnits(-0.8), z: .astronomicalUnits(0.5))
		// A velocity rotates as a position does.
		#expect(v.converted(to: EclipticJ2000.self).vector == p.converted(to: EclipticJ2000.self).vector)
		#expect((EclipticJ2000.rotationFromICRS * v).vector == EclipticJ2000.rotationFromICRS.apply(to: v.vector))
	}

	@Test func description() {
		#expect(Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(1, 0, 0)).description == "(1.0, 0.0, 0.0) au/d ICRS")
	}
}
