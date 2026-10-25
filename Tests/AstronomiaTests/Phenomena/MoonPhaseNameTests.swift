//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct MoonPhaseNameTests {
	static func phase(_ degrees: Double, _ halfWidth: Double = 5) throws -> Moon.PhaseName {
		try Moon.PhaseName(excessEclipticLongitude: .degrees(degrees), principalHalfWidth: .degrees(halfWidth))
	}

	@Test func bins() throws {
		let expected: [(Double, Moon.PhaseName)] = [
			(0, .newMoon), (5, .newMoon), (5.001, .waxingCrescent), (84.999, .waxingCrescent),
			(85, .firstQuarter), (95, .firstQuarter), (95.001, .waxingGibbous),
			(175, .fullMoon), (180, .fullMoon), (185, .fullMoon), (185.001, .waningGibbous),
			(265, .lastQuarter), (275, .lastQuarter), (275.001, .waningCrescent),
			(354.999, .waningCrescent), (355, .newMoon), (359.999, .newMoon),
			// Reduced to [0, 360)°
			(360, .newMoon), (-3, .newMoon), (-45, .waningCrescent), (450, .firstQuarter), (720 + 180, .fullMoon),
		]
		for (degrees, phase) in expected {
			#expect(try Self.phase(degrees) == phase, "\(degrees)°")
		}
		#expect(try Moon.PhaseName(excessEclipticLongitude: .degrees(3)) == .newMoon)
		#expect(Moon.PhaseName.defaultPrincipalHalfWidth == .degrees(5))
	}

	@Test func endsOfThePrincipalPhases() throws {
		// The ends of a principal phase are in it, from any turn, though reducing the angle to a
		// turn and converting it between degrees and radians round it, as -22.5° to
		// 337.49999999999994°.
		let ends: [(Double, Double, Moon.PhaseName)] = [
			(-22.5, 22.5, .newMoon), (22.5, 22.5, .newMoon), (382.5, 22.5, .newMoon), (-337.5, 22.5, .newMoon),
			(-67.5, 22.5, .lastQuarter), (-247.5, 22.5, .firstQuarter), (720 + 112.5, 22.5, .firstQuarter),
			(-85, 5, .lastQuarter), (-95, 5, .lastQuarter), (-175, 5, .fullMoon), (-185, 5, .fullMoon),
			(1085, 5, .newMoon), (-1085, 5, .newMoon), (3600 + 95, 5, .firstQuarter), (-3600 - 265, 5, .firstQuarter),
			(-0.1, 0.1, .newMoon), (-89.9, 0.1, .lastQuarter), (-60, 45, .lastQuarter), (-150, 45, .fullMoon),
		]
		for (degrees, width, phase) in ends {
			#expect(try Self.phase(degrees, width) == phase, "\(degrees)° within \(width)°")
		}
		// Just outside, beyond the roundoff tolerance
		#expect(try Self.phase(-22.500_001, 22.5) == .waningCrescent)
		#expect(try Self.phase(382.500_001, 22.5) == .waxingCrescent)
		#expect(try Self.phase(-84.999_999, 5) == .waningCrescent)
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
		#expect(throws: Moon.PhaseNameError.invalidHalfWidth) { try Self.phase(10, 45.1) }
		#expect(throws: Moon.PhaseNameError.invalidHalfWidth) { try Self.phase(10, -1) }
		#expect(throws: Moon.PhaseNameError.invalidHalfWidth) { try Self.phase(10, .nan) }
		#expect(throws: Moon.PhaseNameError.nonFiniteValue) { try Self.phase(.infinity) }
		#expect(throws: Moon.PhaseNameError.nonFiniteValue) { try Self.phase(.nan) }
	}

	@Test func waxing() throws {
		#expect(Moon.PhaseName.allCases.map(\.isWaxing) == [false, true, true, true, false, false, false, false])
		#expect(Moon.PhaseName.allCases.map(\.isWaning) == [false, false, false, false, false, true, true, true])
	}

	@Test func atThePhasesOfTheMoon() throws {
		// The excess of the illumination is the phases', and each principal phase lasts while
		// the excess is within 5° of it, about 10 hours either side, whatever the Moon's
		// latitude, through every full Moon of 2026.
		let start = Instant<TT>(try JulianDate(year: 2026, month: 1, day: 1))
		let end = Instant<TT>(try JulianDate(year: 2027, month: 1, day: 1))
		let phases = try Moon.phases(from: start, to: end, precision: .arcsecond)
		let names: [Moon.PhaseEvent.Kind: Moon.PhaseName] = [.newMoon: .newMoon, .firstQuarter: .firstQuarter, .fullMoon: .fullMoon, .lastQuarter: .lastQuarter]
		for event in phases {
			let illumination = try Moon.illumination(at: event.instant, precision: .arcsecond)
			let difference = (illumination.excessEclipticLongitude.radians - event.kind.excessEclipticLongitude.radians).remainder(dividingBy: twoPi)
			#expect(abs(difference) < Angle(arcseconds: 1).radians, "\(event)")
			#expect(illumination.moonPhaseName == names[event.kind])
			for hours in [-7.0, 7.0] {
				let near = try Moon.illumination(at: Instant<TT>(try event.instant.julianDate.adding(days: hours / 24)), precision: .arcsecond)
				#expect(near.moonPhaseName == names[event.kind], "\(event) \(hours) h")
			}
			for hours in [-12.0, 12.0] {
				let far = try Moon.illumination(at: Instant<TT>(try event.instant.julianDate.adding(days: hours / 24)), precision: .arcsecond)
				#expect(far.moonPhaseName != names[event.kind], "\(event) \(hours) h")
				#expect(try far.moonPhaseName(principalHalfWidth: .degrees(10)) == names[event.kind], "\(event) \(hours) h")
			}
		}
		#expect(phases.count > 48)
		// Between them, the crescents and gibbous phases, and the Moon east of the Sun while it
		// waxes
		let waxingGibbous = try Moon.illumination(at: Instant<TT>(try phases.first { $0.kind == .firstQuarter }!.instant.julianDate.adding(days: 3)), precision: .arcsecond)
		#expect(waxingGibbous.moonPhaseName == .waxingGibbous && waxingGibbous.isEastOfSun)
		let waningCrescent = try Moon.illumination(at: Instant<TT>(try phases.first { $0.kind == .lastQuarter }!.instant.julianDate.adding(days: 3)), precision: .arcsecond)
		#expect(waningCrescent.moonPhaseName == .waningCrescent && !waningCrescent.isEastOfSun)
	}
}
