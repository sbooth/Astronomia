//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct IlluminationTests {
	/// The Earth orientation of the fixtures: UT1 = TT - 69.2 s, no polar motion or pole offsets.
	static let earthOrientation = EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(69.2)))

	/// The sites of the fixtures, on WGS84.
	static let sites: [Observer] = [
		try! Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005), height: .meters(46)),
		try! Observer.site(latitude: .degrees(19.8207), longitude: .degrees(-155.4681), height: .meters(4205)),
	]

	@Test func matchesSkyfield() throws {
		// The Moon and the planets from the geocenter and from sites, at 0.1": the phase angles
		// within 0.05" of Skyfield's with DE421, the elongations within 0.03", and the bright
		// limbs within 0.03" across the body's elongation
		let ephemeris = BuiltInEphemeris(precision: .tenthArcsecond)
		for expected in skyfieldIllumination {
			let observer = expected.site < 0 ? Observer.geocenter : Self.sites[expected.site]
			let instant = Instant<TT>(try JulianDate(julianDate: expected.julianDate))
			let sky = try observer.observation(at: instant, earthOrientation: Self.earthOrientation, ephemeris: ephemeris)
			let illumination = try sky.illumination(of: expected.body)
			let comment = Comment(rawValue: "\(expected)")
			#expect(abs(illumination.phaseAngle.degrees - expected.phaseAngle) * 3600 <= 0.1, comment)
			#expect(abs(illumination.illuminatedFraction - expected.fraction) <= 3e-7, comment)
			#expect(abs(illumination.elongation.degrees - expected.elongation) * 3600 <= 0.06, comment)
			let limb = Angle(degrees: illumination.brightLimbPositionAngle.degrees - expected.brightLimb).normalizedSigned()
			#expect(abs(limb.degrees) * 3600 * Math.sin(illumination.elongation.radians) <= 0.06, comment)
			#expect(illumination.brightLimbPositionAngle.degrees >= 0 && illumination.brightLimbPositionAngle.degrees < 360)
			#expect(illumination.instant == instant)
		}
		#expect(skyfieldIllumination.count > 300)
	}

	@Test func phasesOfTheMoon() throws {
		// Full near a full Moon and dark near a new Moon, waxing with the bright limb to the
		// west, near 270°, and waning to the east, near 90°
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		for kind in MoonPhaseEvent.Kind.allCases {
			let instant = try MoonPhases.next(kind, after: start, precision: .arcsecond)
			let illumination = try MoonPhases.illumination(at: instant, precision: .arcsecond)
			let limb = illumination.brightLimbPositionAngle.degrees
			switch kind {
			case .newMoon:
				#expect(illumination.illuminatedFraction < 0.005 && illumination.phaseAngle.degrees > 170)
			case .firstQuarter:
				#expect(abs(illumination.illuminatedFraction - 0.5) < 0.01 && limb > 220 && limb < 320)
			case .fullMoon:
				#expect(illumination.illuminatedFraction > 0.995 && illumination.phaseAngle.degrees < 10)
			case .lastQuarter:
				#expect(abs(illumination.illuminatedFraction - 0.5) < 0.01 && limb > 40 && limb < 140)
			}
			// The elongation and the phase angle nearly sum to 180° for the Moon, whose distance
			// is small beside the Sun's.
			#expect(abs(illumination.elongation.degrees + illumination.phaseAngle.degrees - 180) < 0.2)
		}
	}

	@Test func moonPhasesConvenience() throws {
		let instant = Instant<TT>(try JulianDate(julianDate: 2_461_050.3))
		let sky = try Self.sites[1].observation(at: instant, earthOrientation: Self.earthOrientation, ephemeris: BuiltInEphemeris(precision: .arcsecond))
		let expected = try sky.illumination(of: .moon)
		#expect(try MoonPhases.illumination(at: instant, observer: Self.sites[1], earthOrientation: Self.earthOrientation, precision: .arcsecond) == expected)
		// From UTC
		let utc = try instant.converted(to: UTC.self)
		let fromUTC = try MoonPhases.illumination(at: utc, precision: .arcsecond)
		#expect(abs(fromUTC.phaseAngle.degrees - (try MoonPhases.illumination(at: instant, precision: .arcsecond)).phaseAngle.degrees) < 1e-9)
	}

	@Test func notIlluminated() throws {
		let instant = Instant<TT>(try JulianDate(julianDate: 2_461_050.3))
		let ephemeris = BuiltInEphemeris(precision: .tenArcseconds)
		for observer in [Observer.geocenter, Self.sites[0]] {
			let sky = try observer.observation(at: instant, earthOrientation: Self.earthOrientation, ephemeris: ephemeris)
			#expect(throws: IlluminationError.notIlluminated) { try sky.illumination(of: .sun) }
			#expect(throws: IlluminationError.notIlluminated) { try sky.illumination(of: .earth) }
		}
		// Outside the coverage
		let far = Instant<TT>(try JulianDate(julianDate: 3_000_000.5))
		#expect(throws: IlluminationError.ephemeris(.outsideCoverage)) { try MoonPhases.illumination(at: far, precision: .tenArcseconds) }
	}
}
