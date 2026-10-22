//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct DatedFrameTests {
	static let epoch = Instant<TT>(.j2000)
	static let later = Instant<TT>(JulianDate(uncheckedJulianDayNumber: 2_488_070, fractionFromNoon: 0))

	static func au(_ x: Double, _ y: Double, _ z: Double, epoch: Instant<TT> = Self.epoch) -> Position<TestEquatorOfDate> {
		Position(x: Distance(astronomicalUnits: x), y: Distance(astronomicalUnits: y), z: Distance(astronomicalUnits: z), epoch: epoch)
	}

	/// A rotation from the ICRS to the test frame at an epoch, turning the axes about z.
	static func fromICRS(at epoch: Instant<TT>, degrees: Double) -> Rotation<ICRS, TestEquatorOfDate> {
		Rotation<ICRS, ICRS>.aboutZ(Angle(degrees: degrees)).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}

	@Test func fixedFramesTakeNoSpace() {
		#expect(MemoryLayout<NoEpoch>.size == 0)
		#expect(MemoryLayout<Position<ICRS>>.size == 24)
		#expect(MemoryLayout<Velocity<ICRS>>.size == 24)
		#expect(MemoryLayout<StateVector<ICRS>>.size == 48)
		#expect(MemoryLayout<SphericalPosition<ICRS>>.size == 24)
		#expect(MemoryLayout<Rotation<ICRS, EclipticJ2000>>.size == 72)
	}

	@Test func positionsCarryTheirEpoch() throws {
		let a = Self.au(1, 2, 3)
		let b = Self.au(0.5, -1, 2)
		#expect(a.epoch == Self.epoch)
		let sum = try a.adding(b)
		#expect(sum.epoch == Self.epoch && sum.vector == Vector3(1.5, 1, 5))
		let difference = try a.subtracting(b)
		#expect(difference.epoch == Self.epoch && difference.vector == Vector3(0.5, 3, 1))
		#expect((-a).epoch == Self.epoch)
		#expect((a * 2).epoch == Self.epoch && (2 * a).epoch == Self.epoch && (a / 2).epoch == Self.epoch)
		#expect(Position<TestEquatorOfDate>.origin(epoch: Self.later).epoch == Self.later)
		#expect(try a.angularSeparation(from: b) == Position<ICRS>(a.vector).angularSeparation(from: Position(b.vector)))
	}

	@Test func mismatchedEpochsThrow() throws {
		let a = Self.au(1, 2, 3)
		let b = Self.au(0.5, -1, 2, epoch: Self.later)
		let mismatch = CoordinateError.epochMismatch
		#expect(throws: mismatch) { try a.adding(b) }
		#expect(throws: mismatch) { try a.subtracting(b) }
		#expect(throws: mismatch) { try a.angularSeparation(from: b) }
		let v = Velocity<TestEquatorOfDate>.zero(epoch: Self.epoch)
		let w = Velocity<TestEquatorOfDate>.zero(epoch: Self.later)
		#expect(throws: mismatch) { try v.adding(w) }
		#expect(throws: mismatch) { try v.subtracting(w) }
		#expect(throws: mismatch) { try StateVector(position: a, velocity: w) }
		let state = try StateVector(position: a, velocity: v)
		let later = try StateVector(position: b, velocity: w)
		#expect(throws: mismatch) { try state.adding(later) }
		#expect(throws: mismatch) { try state.subtracting(later) }
		// A rotation from the frame at one epoch takes only values at that epoch.
		let rotation = Self.fromICRS(at: Self.epoch, degrees: 10).inverse
		#expect(throws: mismatch) { try rotation.apply(to: b) }
		#expect(throws: mismatch) { try rotation.apply(to: w) }
		#expect(throws: mismatch) { try rotation.composed(after: Self.fromICRS(at: Self.later, degrees: 10)) }
	}

	@Test func epochsDistinguishPositions() {
		let a = Self.au(1, 2, 3)
		let b = Self.au(1, 2, 3, epoch: Self.later)
		#expect(a != b)
		#expect(Set([a, b, Self.au(1, 2, 3)]).count == 2)
	}

	@Test func sphericalKeepsTheEpoch() {
		let p = Self.au(0, 1, 1, epoch: Self.later)
		let spherical = p.spherical
		#expect(spherical.epoch == Self.later)
		#expect(abs(spherical.rightAscension.degrees - 90) <= 1e-12 && abs(spherical.declination.degrees - 45) <= 1e-12)
		let back = Position(spherical)
		#expect(back.epoch == Self.later)
		expectClose(back.vector, p.vector)
		let equatorial = SphericalPosition<TestEquatorOfDate>(rightAscension: Angle(degrees: 90), declination: Angle(degrees: 45), distance: p.distance, epoch: Self.later)
		#expect(equatorial == spherical)
		#expect(SphericalPosition<TestEquatorOfDate>(longitude: Angle(degrees: 90), latitude: Angle(degrees: 45), distance: p.distance, epoch: Self.epoch) != spherical)
	}

	@Test func velocitiesAndStatesCarryTheirEpoch() throws {
		let v = Velocity<TestEquatorOfDate>(astronomicalUnitsPerDay: SIMD3(0, 0.017, 0), epoch: Self.epoch)
		#expect(v.epoch == Self.epoch)
		#expect(try v.adding(v).epoch == Self.epoch && v.subtracting(v).epoch == Self.epoch && (-v).epoch == Self.epoch)
		#expect((v * 2).epoch == Self.epoch && (v / 2).epoch == Self.epoch)
		#expect(v.displacement(overDays: 10).epoch == Self.epoch)
		#expect(Velocity<TestEquatorOfDate>.zero(epoch: Self.later).epoch == Self.later)
		let kms = Velocity<TestEquatorOfDate>(kilometersPerSecond: v.kilometersPerSecond, epoch: Self.epoch)
		expectClose(kms.vector, v.vector, 1e-17)
		#expect(kms.epoch == Self.epoch)

		let state = try StateVector(position: Self.au(1, 0, 0), velocity: v)
		#expect(state.epoch == Self.epoch)
		#expect(try state.adding(state).epoch == Self.epoch && state.subtracting(state).epoch == Self.epoch)
		#expect((-state).epoch == Self.epoch && (state * 0.5).epoch == Self.epoch)
	}

	@Test func rotationsTakeAndGiveEpochs() throws {
		let rotation = Self.fromICRS(at: Self.later, degrees: 90)
		#expect(rotation.toEpoch == Self.later)
		// Rotating the axes by 90° about z puts the old x axis along the new -y axis.
		let icrs = PositionTests.au(1, 0, 0)
		let dated = rotation * icrs
		#expect(dated.epoch == Self.later)
		expectClose(dated.vector, Vector3(0, -1, 0))
		// The inverse takes the position back to the ICRS, and the round trip is the identity.
		#expect(rotation.inverse.fromEpoch == Self.later)
		expectClose(try rotation.inverse.apply(to: dated).vector, icrs.vector)
		expectRows(try rotation.inverse.composed(after: rotation), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
		let velocity = rotation * Velocity<ICRS>(astronomicalUnitsPerDay: SIMD3(1, 0, 0))
		#expect(velocity.epoch == Self.later)
		expectClose(velocity.vector, Vector3(0, -1, 0))
	}

	@Test func rotationsBetweenEpochsOfOneFrame() throws {
		// As precession from one date to another: from the frame at one epoch to the same
		// frame at a later one.
		let start = Self.fromICRS(at: Self.epoch, degrees: 10)
		let end = Self.fromICRS(at: Self.later, degrees: 30)
		let between: Rotation<TestEquatorOfDate, TestEquatorOfDate> = end * start.inverse
		#expect(between.fromEpoch == Self.epoch && between.toEpoch == Self.later)
		let moved = try between.apply(to: Self.au(1, 0, 0))
		#expect(moved.epoch == Self.later)
		expectClose(moved.vector, Vector3(Math.cos(Double.pi / 9), -Math.sin(Double.pi / 9), 0))
		// The same rows with other epochs are another rotation.
		#expect(between != end * Self.fromICRS(at: Self.later, degrees: 10).inverse)
	}

	@Test func descriptionsShowTheEpoch() {
		#expect(Self.au(1, 0, 0).description == "(1.0, 0.0, 0.0) au Test equator of date at \(Self.epoch)")
		#expect(PositionTests.au(1, 0, 0).description == "(1.0, 0.0, 0.0) au ICRS")
		let v = Velocity<TestEquatorOfDate>(astronomicalUnitsPerDay: SIMD3(0, 1, 0), epoch: Self.later)
		#expect(v.description == "(0.0, 1.0, 0.0) au/d Test equator of date at \(Self.later)")
	}
}
