//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct PositionTests {
	static func au(_ x: Double, _ y: Double, _ z: Double) -> Position<ICRS> {
		Position(x: Distance(astronomicalUnits: x), y: Distance(astronomicalUnits: y), z: Distance(astronomicalUnits: z))
	}

	@Test func components() {
		let p = Self.au(3, -4, 12)
		#expect(p.x == Distance(astronomicalUnits: 3))
		#expect(p.y == Distance(astronomicalUnits: -4))
		#expect(p.z == Distance(astronomicalUnits: 12))
		#expect(p.distance == Distance(astronomicalUnits: 13))
		#expect(Position<ICRS>.origin.distance == .zero)
	}

	@Test func arithmetic() {
		let a = Self.au(1, 2, 3)
		let b = Self.au(0.5, -1, 2)
		#expect(a + b == Self.au(1.5, 1, 5))
		#expect(a - b == Self.au(0.5, 3, 1))
		#expect(-a == Self.au(-1, -2, -3))
		#expect(a * 2 == Self.au(2, 4, 6))
		#expect(2 * a == Self.au(2, 4, 6))
	}

	@Test func sphericalRoundTrip() {
		for (lon, lat) in [(0.0, 0.0), (45.0, 30.0), (190.0, -75.0), (359.9, 89.9), (123.0, -0.001)] {
			let spherical = SphericalPosition<ICRS>(longitude: Angle(degrees: lon), latitude: Angle(degrees: lat), distance: Distance(astronomicalUnits: 2.5))
			let back = Position(spherical).spherical
			#expect(abs(back.longitude.degrees - lon) <= 1e-12, "\(lon)")
			#expect(abs(back.latitude.degrees - lat) <= 1e-12, "\(lat)")
			#expect(abs(back.distance.astronomicalUnits - 2.5) <= 1e-15)
		}
	}

	@Test func sphericalSpecialPoints() {
		// Longitude is reduced to [0, 2π), and is zero at the origin and on the z axis.
		let west = Self.au(0, -1, 0).spherical
		#expect(abs(west.longitude.degrees - 270) <= 1e-12)
		let pole = Self.au(0, 0, 2).spherical
		#expect(pole.longitude == .zero && pole.latitude.degrees == 90 && pole.distance.astronomicalUnits == 2)
		let origin = Position<ICRS>.origin.spherical
		#expect(origin.longitude == .zero && origin.latitude == .zero && origin.distance == .zero)
		// Near the pole the latitude is resolved to the spacing of doubles near π/2, where
		// the arcsine of z / r would round to the pole itself.
		let nearPole = Self.au(1e-12, 0, 1).spherical
		#expect(abs((Double.pi / 2 - nearPole.latitude.radians) - 1e-12) <= 3e-16)
	}

	@Test func sphericalSignedZeros() {
		// Negation and scaling give negative zeros, for which the arctangent of the
		// horizontal components would give 180°. The longitude on the z axis is still zero.
		let negatedOrigin = (-Position<ICRS>.origin).spherical
		#expect(negatedOrigin.longitude == .zero && negatedOrigin.latitude == .zero && negatedOrigin.distance == .zero)
		let scaledOrigin = (Position<ICRS>.origin * -1).spherical
		#expect(scaledOrigin.longitude == .zero && scaledOrigin.latitude == .zero)
		let southPole = (-Self.au(0, 0, 2)).spherical
		#expect(southPole.longitude == .zero && southPole.latitude.degrees == -90 && southPole.distance.astronomicalUnits == 2)
		let northPole = (-Self.au(0, 0, -2)).spherical
		#expect(northPole.longitude == .zero && northPole.latitude.degrees == 90)
		let scaledPole = (Self.au(0, 0, 1) * -3).spherical
		#expect(scaledPole.longitude == .zero && scaledPole.latitude.degrees == -90)
		// Off the axis, the signs of the coordinates still choose the quadrant.
		#expect(abs((-Self.au(1, 0, 0)).spherical.longitude.degrees - 180) <= 1e-12)
		#expect(abs((-Self.au(0, 1, 5)).spherical.longitude.degrees - 270) <= 1e-12)
	}

	@Test func equatorialNames() {
		let spherical = SphericalPosition<ICRS>(rightAscension: Angle(hourAngle: 18), declination: Angle(degrees: -30), distance: Distance(astronomicalUnits: 1))
		#expect(spherical.rightAscension == spherical.longitude)
		#expect(spherical.declination == spherical.latitude)
		#expect(abs(spherical.rightAscension.hourAngle - 18) <= 1e-14)
	}

	@Test func angularSeparation() {
		let a = Self.au(1, 0, 0)
		#expect(abs(a.angularSeparation(from: Self.au(0, 5, 0)).degrees - 90) <= 1e-12)
		#expect(abs(a.angularSeparation(from: Self.au(-2, 0, 0)).degrees - 180) <= 1e-12)
		// A tiny separation is resolved, where the arccosine of the dot product would give 0.
		let tiny = a.angularSeparation(from: Self.au(1, 1e-10, 0))
		#expect(abs(tiny.radians - 1e-10) <= 1e-24)
		#expect(a.angularSeparation(from: .origin) == .zero)
	}

	@Test func angularSeparationFromTheOrigin() {
		// The dot product with the origin is -0 for negative coordinates, where the arctangent
		// would give 180°. Either operand order, and the origin negated, gives zero.
		let p = Self.au(-1, -1, -1)
		#expect(p.angularSeparation(from: .origin) == .zero)
		#expect(Position<ICRS>.origin.angularSeparation(from: p) == .zero)
		#expect(p.angularSeparation(from: -.origin) == .zero)
		#expect((-Position<ICRS>.origin).angularSeparation(from: p) == .zero)
		#expect(Position<ICRS>.origin.angularSeparation(from: .origin) == .zero)
	}

	@Test func northEclipticPole() {
		// The pole of the J2000 ecliptic, from SOFA iauEcm06: RA 269.99998529777776°,
		// Dec 66.56071866138889°
		let pole = Position<EclipticJ2000>(x: .zero, y: .zero, z: Distance(astronomicalUnits: 1))
		let icrs = pole.converted(to: ICRS.self).spherical
		#expect(abs(icrs.rightAscension.degrees - 269.999_985_297_777_76) <= 1e-11)
		#expect(abs(icrs.declination.degrees - 66.560_718_661_388_89) <= 1e-11)
	}

	@Test func conversionRoundTrip() {
		let p = Self.au(0.3, -0.8, 0.5)
		let back = p.converted(to: EclipticJ2000.self).converted(to: ICRS.self)
		expectClose(back.vector, p.vector)
		#expect(p.converted(to: ICRS.self) == p)
	}

	@Test func description() {
		#expect(Self.au(1, 0, 0).description == "(1.0, 0.0, 0.0) au ICRS")
	}
}
