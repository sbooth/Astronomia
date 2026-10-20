//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Expects two vectors to agree component by component to within `tolerance`.
func expectClose(_ a: Vector3, _ b: Vector3, _ tolerance: Double = 1e-15, sourceLocation: SourceLocation = #_sourceLocation) {
	let d = a - b
	#expect(max(abs(d.x), abs(d.y), abs(d.z)) <= tolerance, "\(a) vs \(b)", sourceLocation: sourceLocation)
}

/// Expects a rotation's matrix to agree with `rows` element by element to within `tolerance`.
func expectRows<A, B>(_ rotation: Rotation<A, B>, _ rows: [[Double]], _ tolerance: Double = 1e-15, sourceLocation: SourceLocation = #_sourceLocation) {
	let actual = [rotation.rows.0, rotation.rows.1, rotation.rows.2]
	for (row, expected) in zip(actual, rows) {
		expectClose(Vector3(row.x, row.y, row.z), Vector3(expected[0], expected[1], expected[2]), tolerance, sourceLocation: sourceLocation)
	}
}

/// A frame defined outside the library, as an app might define galactic coordinates.
private enum Turned: EquatorialFrame, FixedReferenceFrame {
	static let name = "Turned"
	static let rotationFromICRS = Rotation<ICRS, Turned>.aboutZ(Angle(degrees: 90))
}

@Suite struct RotationTests {
	typealias R = Rotation<ICRS, ICRS>

	@Test func elementaryRotationsMoveTheAxes() {
		// Rotating the axes by 90° about z puts the old x axis along the new -y axis.
		expectClose(R.aboutZ(Angle(degrees: 90)).apply(to: Vector3(1, 0, 0)), Vector3(0, -1, 0))
		expectClose(R.aboutX(Angle(degrees: 90)).apply(to: Vector3(0, 1, 0)), Vector3(0, 0, -1))
		expectClose(R.aboutY(Angle(degrees: 90)).apply(to: Vector3(0, 0, 1)), Vector3(-1, 0, 0))
	}

	@Test func compositionAppliesRightToLeft() {
		let first = R.aboutZ(Angle(degrees: 30))
		let second = R.aboutX(Angle(degrees: 50))
		let v = Vector3(0.3, -0.8, 0.5)
		expectClose((second * first).apply(to: v), second.apply(to: first.apply(to: v)))
		// The two orders differ, so the test distinguishes them.
		#expect(((first * second).apply(to: v) - (second * first).apply(to: v)).length > 0.1)
	}

	@Test func inverse() {
		let rotation = R.aboutY(Angle(degrees: 12)) * R.aboutZ(Angle(degrees: -73)) * R.aboutX(Angle(degrees: 40))
		let v = Vector3(0.3, -0.8, 0.5)
		expectClose(rotation.inverse.apply(to: rotation.apply(to: v)), v)
		expectClose(rotation.applyInverse(to: v), rotation.inverse.apply(to: v))
		expectRows(rotation.inverse * rotation, [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
	}

	@Test func eclipticJ2000MatchesSOFA() {
		// SOFA iauEcm06 at JD 2451545.0 TT, from ERFA 2.0.1.5
		expectRows(EclipticJ2000.rotationFromICRS, [
			[0.9999999999999941, -7.078368960971556e-08, 8.056213977613186e-08],
			[3.2897004077419646e-08, 0.9174821299149584, 0.39777699944404793],
			[-1.0207044725484355e-07, -0.39777699944404304, 0.9174821299149556],
		])
	}

	@Test func fixedFrames() {
		expectRows(ICRS.rotation(to: ICRS.self), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
		expectRows(EclipticJ2000.rotation(to: EclipticJ2000.self), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
		expectRows(EclipticJ2000.rotation(to: ICRS.self) * ICRS.rotation(to: EclipticJ2000.self), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
	}

	@Test func rowsMatchApplication() {
		let rotation = R.aboutY(Angle(degrees: 12)) * R.aboutZ(Angle(degrees: -73))
		let v = Vector3(0.3, -0.8, 0.5)
		let (r0, r1, r2) = rotation.rows
		let simdV = SIMD3(v.x, v.y, v.z)
		expectClose(rotation.apply(to: v), Vector3((r0 * simdV).sum(), (r1 * simdV).sum(), (r2 * simdV).sum()))
	}

	@Test func userDefinedFrame() {
		let p = Position<ICRS>(x: Distance(astronomicalUnits: 1), y: .zero, z: .zero)
		let turned = p.converted(to: Turned.self)
		expectClose(turned.vector, Vector3(0, -1, 0))
		#expect(abs(turned.spherical.rightAscension.degrees - 270) <= 1e-12)
		expectClose(turned.converted(to: EclipticJ2000.self).vector, p.converted(to: EclipticJ2000.self).vector)
		expectRows(Turned.rotation(to: Turned.self), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
	}

	@Test func rotatesPositions() {
		let p = Position<ICRS>(x: Distance(astronomicalUnits: 0.3), y: Distance(astronomicalUnits: -0.8), z: Distance(astronomicalUnits: 0.5))
		let q = EclipticJ2000.rotationFromICRS * p
		// SOFA: iauEcm06 applied to the same vector
		expectClose(q.vector, Vector3(0.30000009690801976, -0.5350971943408416, 0.776962633891578))
	}
}
