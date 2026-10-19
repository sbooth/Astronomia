//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct StateVectorTests {
	// Values exact in binary, so the arithmetic is exact
	static let a = StateVector<ICRS>(Vector3(1, 2, 3), Vector3(0.25, 0.5, 0.75))
	static let b = StateVector<ICRS>(Vector3(0.5, -1, 0), Vector3(-0.25, 0, 0.125))

	@Test func arithmetic() {
		let sum = Self.a + Self.b
		#expect(sum.position.vector == Vector3(1.5, 1, 3))
		#expect(sum.velocity.vector == Vector3(0, 0.5, 0.875))
		let difference = Self.a - Self.b
		#expect(difference.position.vector == Vector3(0.5, 3, 3))
		#expect(difference.velocity.vector == Vector3(0.5, 0.5, 0.625))
		#expect((-Self.a).position.vector == Vector3(-1, -2, -3))
		#expect((-Self.a).velocity.vector == Vector3(-0.25, -0.5, -0.75))
		#expect(difference + Self.b == Self.a)
	}

	@Test func conversion() {
		let converted = Self.a.converted(to: EclipticJ2000.self)
		#expect(converted.position == Self.a.position.converted(to: EclipticJ2000.self))
		#expect(converted.velocity == Self.a.velocity.converted(to: EclipticJ2000.self))
	}

	@Test func components() {
		let state = StateVector(position: Self.a.position, velocity: Self.a.velocity)
		#expect(state == Self.a)
		#expect(state.description == "position (1.0, 2.0, 3.0) au ICRS, velocity (0.25, 0.5, 0.75) au/d ICRS")
	}
}
