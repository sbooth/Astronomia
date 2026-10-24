//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct MoonPhaseNameTests {
	static func phase(_ degrees: Double, _ halfWidth: Double = 5) throws -> MoonPhaseName {
		try MoonPhaseName(excessEclipticLongitude: .degrees(degrees), principalHalfWidth: .degrees(halfWidth))
	}

	@Test func bins() throws {
		let expected: [(Double, MoonPhaseName)] = [
			(0, .newMoon), (5, .newMoon), (5.001, .waxingCrescent), (84.999, .waxingCrescent),
			(85, .firstQuarter), (95, .firstQuarter), (95.001, .waxingGibbous),
			(175, .fullMoon), (180, .fullMoon), (185, .fullMoon), (185.001, .waningGibbous),
			(265, .lastQuarter), (275, .lastQuarter), (275.001, .waningCrescent),
			(354.999, .waningCrescent), (355, .newMoon), (359.999, .newMoon),
			// Reduced to [0°, 360°)
			(360, .newMoon), (-3, .newMoon), (-45, .waningCrescent), (450, .firstQuarter), (720 + 180, .fullMoon),
		]
		for (degrees, phase) in expected {
			#expect(try Self.phase(degrees) == phase, "\(degrees)°")
		}
		#expect(try MoonPhaseName(excessEclipticLongitude: .degrees(3)) == .newMoon)
		#expect(MoonPhaseName.defaultPrincipalHalfWidth == .degrees(5))
	}

	@Test func halfWidths() throws {
		// No width: a principal phase only at its value
		#expect(try Self.phase(0, 0) == .newMoon && Self.phase(0.001, 0) == .waxingCrescent)
		#expect(try Self.phase(180, 0) == .fullMoon && Self.phase(179.999, 0) == .waxingGibbous)
		// The widest: the principal phases only, sharing their ends
		for degrees in stride(from: 0.0, to: 360, by: 7.5) {
			let phase = try Self.phase(degrees, 45)
			#expect([.newMoon, .firstQuarter, .fullMoon, .lastQuarter].contains(phase), "\(degrees)°")
		}
		#expect(try Self.phase(44.9, 45) == .newMoon && Self.phase(45.1, 45) == .firstQuarter)
		#expect(throws: MoonPhaseNameError.invalidHalfWidth) { try Self.phase(10, 45.1) }
		#expect(throws: MoonPhaseNameError.invalidHalfWidth) { try Self.phase(10, -1) }
		#expect(throws: MoonPhaseNameError.invalidHalfWidth) { try Self.phase(10, .nan) }
		#expect(throws: MoonPhaseNameError.nonFiniteValue) { try Self.phase(.infinity) }
		#expect(throws: MoonPhaseNameError.nonFiniteValue) { try Self.phase(.nan) }
	}

	@Test func waxing() throws {
		#expect(MoonPhaseName.allCases.map(\.isWaxing) == [false, true, true, true, false, false, false, false])
		#expect(MoonPhaseName.allCases.map(\.isWaning) == [false, false, false, false, false, true, true, true])
	}

	@Test func atThePhasesOfTheMoon() throws {
		// The excess of the illumination is the phases', and each principal phase lasts while
		// the excess is within 5° of it, about 10 hours either side, whatever the Moon's
		// latitude, through every full Moon of 2026.
		let start = Instant<TT>(try JulianDate(year: 2026, month: 1, day: 1))
		let end = Instant<TT>(try JulianDate(year: 2027, month: 1, day: 1))
		let phases = try MoonPhases.events(from: start, to: end, precision: .arcsecond)
		let names: [MoonPhaseEvent.Kind: MoonPhaseName] = [.newMoon: .newMoon, .firstQuarter: .firstQuarter, .fullMoon: .fullMoon, .lastQuarter: .lastQuarter]
		for event in phases {
			let illumination = try MoonPhases.illumination(at: event.instant, precision: .arcsecond)
			let difference = (illumination.excessEclipticLongitude.radians - event.kind.excessEclipticLongitude.radians).remainder(dividingBy: twoPi)
			#expect(abs(difference) < Angle(arcseconds: 1).radians, "\(event)")
			#expect(illumination.moonPhaseName == names[event.kind])
			for hours in [-7.0, 7.0] {
				let near = try MoonPhases.illumination(at: Instant<TT>(try event.instant.julianDate.adding(days: hours / 24)), precision: .arcsecond)
				#expect(near.moonPhaseName == names[event.kind], "\(event) \(hours) h")
			}
			for hours in [-12.0, 12.0] {
				let far = try MoonPhases.illumination(at: Instant<TT>(try event.instant.julianDate.adding(days: hours / 24)), precision: .arcsecond)
				#expect(far.moonPhaseName != names[event.kind], "\(event) \(hours) h")
				#expect(try far.moonPhaseName(principalHalfWidth: .degrees(10)) == names[event.kind], "\(event) \(hours) h")
			}
		}
		#expect(phases.count > 48)
		// Between them, the crescents and gibbous phases, and the Moon east of the Sun while it
		// waxes
		let waxingGibbous = try MoonPhases.illumination(at: Instant<TT>(try phases.first { $0.kind == .firstQuarter }!.instant.julianDate.adding(days: 3)), precision: .arcsecond)
		#expect(waxingGibbous.moonPhaseName == .waxingGibbous && waxingGibbous.isEastOfSun)
		let waningCrescent = try MoonPhases.illumination(at: Instant<TT>(try phases.first { $0.kind == .lastQuarter }!.instant.julianDate.adding(days: 3)), precision: .arcsecond)
		#expect(waningCrescent.moonPhaseName == .waningCrescent && !waningCrescent.isEastOfSun)
	}
}
