//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Returns `true` if two values agree to within `tolerance`.
private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-12) -> Bool {
	Swift.abs(a - b) <= tolerance
}

@Suite struct AngleTests {
	@Test func units() {
		#expect(Angle(degrees: 180).radians == .pi)
		#expect(Angle(degrees: 90).radians == .pi / 2)
		#expect(Angle(hourAngle: 12).radians == .pi)
		#expect(Angle(arcseconds: 648_000).radians == .pi)
		#expect(close(Angle(arcminutes: 60).degrees, 1))
		#expect(close(Angle(arcseconds: 3_600).degrees, 1))
		#expect(close(Angle(milliarcseconds: 1_000).arcseconds, 1))
		#expect(close(Angle(hourAngle: 1).degrees, 15))
		#expect(close(Angle(degrees: 15).hourAngle, 1))
		#expect(close(Angle(degrees: 1).arcminutes, 60))
		#expect(close(Angle(degrees: 1).milliarcseconds, 3_600_000, 1e-6))
		#expect(Angle(radians: .pi).degrees == 180)
	}

	@Test(arguments: [0.0, 30, -45, 123.456, 359.999, 1e6, -1e-9])
	func roundTrip(degrees: Double) {
		// Conversions round, so a round trip agrees to within a few ulps.
		let tolerance = 4 * Swift.max(Swift.abs(degrees), 1) * Double.ulpOfOne
		#expect(close(Angle(degrees: degrees).degrees, degrees, tolerance))
		#expect(close(Angle(arcseconds: degrees * 3_600).arcseconds, degrees * 3_600, 3_600 * tolerance))
		#expect(close(Angle(hourAngle: degrees / 15).hourAngle, degrees / 15, tolerance))
	}

	@Test func normalized() {
		let turn = 2 * Double.pi
		#expect(Angle(degrees: 370).normalized().radians == Angle(degrees: 370).radians - turn)
		#expect(close(Angle(degrees: -10).normalized().degrees, 350, 1e-12))
		#expect(Angle.zero.normalized() == .zero)
		#expect(Angle(radians: turn).normalized() == .zero)
		#expect(Angle(radians: -turn).normalized().radians == 0)
		#expect(Angle(radians: .pi).normalized().radians == .pi)
		// A tiny negative angle would round up to a whole turn.
		#expect(Angle(radians: -1e-20).normalized() == .zero)
		#expect(close(Angle(degrees: 481_267.88).normalized().degrees, 307.88, 1e-9))
		for degrees in stride(from: -1_000.0, through: 1_000, by: 7.3) {
			let r = Angle(degrees: degrees).normalized().radians
			#expect(r >= 0 && r < turn)
		}
	}

	@Test func normalizedSigned() {
		#expect(close(Angle(degrees: 190).normalizedSigned().degrees, -170))
		#expect(close(Angle(degrees: -190).normalizedSigned().degrees, 170))
		#expect(Angle(radians: .pi).normalizedSigned().radians == -.pi)
		#expect(Angle(radians: -.pi).normalizedSigned().radians == -.pi)
		#expect(Angle(radians: 3 * .pi).normalizedSigned().radians == -.pi)
		#expect(Angle(radians: 1e-20).normalizedSigned().radians == 1e-20)
		for degrees in stride(from: -1_000.0, through: 1_000, by: 7.3) {
			let r = Angle(degrees: degrees).normalizedSigned().radians
			#expect(r >= -.pi && r < .pi)
			#expect(close((Angle(degrees: degrees).normalized() - Angle(radians: r)).normalizedSigned().radians, 0, 1e-12))
		}
	}

	@Test func trigonometry() {
		let angle = Angle(degrees: 30)
		#expect(close(angle.sin, 0.5))
		#expect(close(angle.cos, 3.0.squareRoot() / 2))
		#expect(close(angle.tan, 1 / 3.0.squareRoot()))
		let (s, c) = angle.sinCos
		#expect(s == angle.sin && c == angle.cos)

		#expect(close(Angle.asin(0.5).degrees, 30))
		#expect(close(Angle.acos(0.5).degrees, 60))
		#expect(close(Angle.atan(1).degrees, 45))
		#expect(Angle.asin(2).radians.isNaN)
	}

	@Test func atan2Quadrants() {
		#expect(close(Angle.atan2(y: 1, x: 1).degrees, 45))
		#expect(close(Angle.atan2(y: 1, x: -1).degrees, 135))
		#expect(close(Angle.atan2(y: -1, x: -1).degrees, -135))
		#expect(close(Angle.atan2(y: -1, x: 1).degrees, -45))
		#expect(close(Angle.atan2(y: -1, x: 1).normalized().degrees, 315))
		#expect(Angle.atan2(y: 0, x: -1).radians == .pi)
	}

	@Test func arithmetic() {
		let a = Angle(degrees: 30)
		let b = Angle(degrees: 45)
		#expect(close((a + b).degrees, 75))
		#expect(close((a - b).degrees, -15))
		#expect((-a).radians == -a.radians)
		#expect(close((a * 3).degrees, 90))
		#expect(close((3 * a).degrees, 90))
		#expect(close((a / 2).degrees, 15))
		#expect(close(b / a, 1.5))
		#expect(a + .zero == a)
		#expect(Angle(degrees: -30).magnitude == a)

		var c = a
		c += b
		c -= a
		c *= 2
		c /= 3
		#expect(close(c.degrees, 30))
	}

	@Test func comparison() {
		// No reduction: 350° is greater than -10°
		#expect(Angle(degrees: -10) < Angle(degrees: 350))
		#expect(Angle(degrees: 360) != .zero)
		#expect(Angle(radians: 0) == Angle(radians: -0.0))
		#expect(Set([Angle(radians: 0), Angle(radians: -0.0)]).count == 1)
	}

	@Test func description() {
		#expect(Angle(degrees: 90).description == "90.0°")
	}
}

#if canImport(Foundation)

import Foundation

@Suite struct AngleCodableTests {
	@Test func codable() throws {
		let angle = Angle(radians: 1.25)
		let data = try JSONEncoder().encode(angle)
		#expect(String(decoding: data, as: UTF8.self) == "1.25")
		#expect(try JSONDecoder().decode(Angle.self, from: data) == angle)
	}
}

#endif

@Suite struct AngleFactoryTests {
	@Test(arguments: [0.0, -0.0, 1, -2.5, 30, 359.999, 1e-9, 1e9, .infinity])
	func factoriesMatchInitializers(value: Double) {
		// Each static method is the initializer of the same unit, bit for bit.
		#expect(Angle.radians(value).radians.bitPattern == Angle(radians: value).radians.bitPattern)
		#expect(Angle.degrees(value).radians.bitPattern == Angle(degrees: value).radians.bitPattern)
		#expect(Angle.arcminutes(value).radians.bitPattern == Angle(arcminutes: value).radians.bitPattern)
		#expect(Angle.arcseconds(value).radians.bitPattern == Angle(arcseconds: value).radians.bitPattern)
		#expect(Angle.milliarcseconds(value).radians.bitPattern == Angle(milliarcseconds: value).radians.bitPattern)
		#expect(Angle.hourAngle(value).radians.bitPattern == Angle(hourAngle: value).radians.bitPattern)
	}

	@Test func nanPropagates() {
		#expect(Angle.degrees(.nan).radians.isNaN)
		#expect(Angle.hourAngle(.nan).radians.isNaN)
	}

	@Test func usableWhereTheTypeIsKnown() {
		// The leading-dot form works wherever an Angle is expected.
		let right: Angle = .degrees(90)
		#expect(right.radians == .pi / 2)
		#expect(Angle(hourAngle: 12) == .radians(.pi))
		#expect(.degrees(30) + .arcminutes(30) == Angle(degrees: 30) + Angle(arcminutes: 30))
		#expect(Angle.arcseconds(1) < .arcminutes(1))
		#expect([Angle.degrees(10), .degrees(-5), .degrees(3)].max() == .degrees(10))
	}
}
