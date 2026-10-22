//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

// Frames of date defined as a client would, with only the public interface.
import Astronomia
import Testing

/// A frame of date for the tests, standing in for the equator of date: the ICRS axes at every
/// epoch.
enum TestEquatorOfDate: EquatorialFrame, DatedReferenceFrame {
	static let name = "Test equator of date"

	static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TestEquatorOfDate> {
		Rotation<ICRS, ICRS>.identity.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

/// The true equator of date with its axes turned by 1° about the pole, built on another frame
/// of date as the ``DatedReferenceFrame`` documentation shows.
enum OffsetEquatorOfDate: EquatorialFrame, DatedReferenceFrame {
	static let name = "Offset equator of date"

	static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, OffsetEquatorOfDate> {
		let trueEquator: Rotation<ICRS, ICRS> = TrueEquatorOfDate.rotationFromICRS(at: epoch, earthOrientation: earthOrientation)
			.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: NoEpoch())
		return (Rotation<ICRS, ICRS>.aboutZ(.degrees(1)) * trueEquator).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

@Suite struct CustomFrameTests {
	static let tt = Instant<TT>(JulianDate.j2000)
	static let later = Instant<TT>(try! JulianDate(julianDayNumber: 2_461_335))
	static let icrs = Position<ICRS>(x: .astronomicalUnits(0.3), y: .astronomicalUnits(-0.8), z: .astronomicalUnits(0.5))

	@Test func identityFrameOfDate() {
		let rotation = TestEquatorOfDate.rotationFromICRS(at: Self.later)
		#expect(rotation.toEpoch == Self.later)
		#expect(rotation.rows == (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)))
		let position = Self.icrs.converted(to: TestEquatorOfDate.self, at: Self.later)
		#expect(position.epoch == Self.later)
		#expect(position.x == Self.icrs.x && position.y == Self.icrs.y && position.z == Self.icrs.z)
	}

	@Test func frameBuiltOnAnotherFrameOfDate() throws {
		let trueEquator = Self.icrs.converted(to: TrueEquatorOfDate.self, at: Self.later).spherical
		let offset = Self.icrs.converted(to: OffsetEquatorOfDate.self, at: Self.later)
		#expect(offset.epoch == Self.later)
		// Turning the axes by 1° about the pole lowers the right ascension by 1°.
		let spherical = offset.spherical
		var difference = (trueEquator.rightAscension.degrees - spherical.rightAscension.degrees).truncatingRemainder(dividingBy: 360)
		if difference < 0 {
			difference += 360
		}
		#expect(abs(difference - 1) <= 1e-12)
		#expect(abs(spherical.declination.degrees - trueEquator.declination.degrees) <= 1e-12)
		// Back to the ICRS, and to the true equator at the same epoch
		let back = offset.converted(to: ICRS.self)
		#expect(abs(back.x.astronomicalUnits - Self.icrs.x.astronomicalUnits) <= 1e-15)
		#expect(abs(back.y.astronomicalUnits - Self.icrs.y.astronomicalUnits) <= 1e-15)
		#expect(abs(back.z.astronomicalUnits - Self.icrs.z.astronomicalUnits) <= 1e-15)
		let viaRotation = try OffsetEquatorOfDate.rotation(from: Self.later, to: TrueEquatorOfDate.self, at: Self.later).apply(to: offset)
		#expect(viaRotation.epoch == Self.later)
		#expect(abs(viaRotation.spherical.rightAscension.degrees - trueEquator.rightAscension.degrees) <= 1e-12)
	}

	@Test func epochsStillChecked() {
		let rotation = OffsetEquatorOfDate.rotation(from: Self.tt, to: ICRS.self)
		let atLater = Self.icrs.converted(to: OffsetEquatorOfDate.self, at: Self.later)
		#expect(throws: CoordinateError.epochMismatch) { try rotation.apply(to: atLater) }
	}
}
