//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The name of the phase of the Moon at an instant, one of eight, as "Waxing Gibbous".
///
/// Where ``MoonPhases`` finds the instants of the four principal phases, each a
/// ``MoonPhaseEvent``, a name says which phase the Moon is in at any instant, from its
/// ``Illumination``.
///
/// The phase follows the excess of the Moon's apparent ecliptic longitude over the Sun's,
/// which the principal phases are named for: new Moon at 0°, first quarter at 90°, full Moon at
/// 180°, and last quarter at 270°. A principal phase lasts while the excess is within a
/// half-width of its value, by default 5°, about 10 hours either side of the instant of the
/// phase that ``MoonPhases`` finds, as the excess grows by between 10.8° and 14.4° a day, and
/// the crescents and gibbous phases fill the time between.
///
/// ```swift
/// let moon = try MoonPhases.illumination(at: instant)
/// print(moon.moonPhaseName)  // waxingGibbous
/// ```
public enum MoonPhaseName: Hashable, Sendable, CaseIterable {
	/// New Moon: the excess is within the half-width of 0°.
	case newMoon
	/// Waxing crescent: from new Moon to first quarter.
	case waxingCrescent
	/// First quarter: the excess is within the half-width of 90°.
	case firstQuarter
	/// Waxing gibbous: from first quarter to full Moon.
	case waxingGibbous
	/// Full Moon: the excess is within the half-width of 180°.
	case fullMoon
	/// Waning gibbous: from full Moon to last quarter.
	case waningGibbous
	/// Last quarter: the excess is within the half-width of 270°.
	case lastQuarter
	/// Waning crescent: from last quarter to new Moon.
	case waningCrescent

	/// The tolerance of the ends of a principal phase for roundoff, in radians, 1e-12, about
	/// 2e-7".
	static var roundoffTolerance: Double { 1e-12 }

	/// The default half-width of a principal phase, 5°.
	public static var defaultPrincipalHalfWidth: Angle { .degrees(5) }

	/// Creates the phase of an excess of the Moon's ecliptic longitude over the Sun's.
	///
	/// A principal phase includes the ends of its interval, within the roundoff of reducing
	/// and converting the angles, so with a half-width of 45° the principal phases are the only
	/// ones.
	///
	/// - Parameters:
	///   - excessEclipticLongitude: The excess of the Moon's ecliptic longitude over the Sun's,
	///     any angle, which is reduced to the right-open interval [0°, 360°).
	///   - principalHalfWidth: The half-width of a principal phase, in the closed interval
	///     [0°, 45°], by default 5°.
	/// - Throws:
	///   - ``MoonPhaseNameError/nonFiniteValue`` if `excessEclipticLongitude` is NaN or infinite.
	///   - ``MoonPhaseNameError/invalidHalfWidth`` if `principalHalfWidth` is NaN, infinite, or
	///     outside the closed interval [0°, 45°].
	public init(excessEclipticLongitude: Angle, principalHalfWidth: Angle = MoonPhaseName.defaultPrincipalHalfWidth) throws(MoonPhaseNameError) {
		guard excessEclipticLongitude.radians.isFinite else {
			throw .nonFiniteValue
		}
		let width = principalHalfWidth.degrees
		guard width.isFinite, width >= 0, width <= 45 else {
			throw .invalidHalfWidth
		}
		self.init(uncheckedExcessEclipticLongitude: excessEclipticLongitude, principalHalfWidth: principalHalfWidth)
	}

	/// Creates the phase of an excess of the Moon's ecliptic longitude over the Sun's, without
	/// checking the arguments.
	///
	/// - Precondition: `excessEclipticLongitude` is finite, and `principalHalfWidth` is in the
	///   closed interval [0°, 45°].
	init(uncheckedExcessEclipticLongitude excessEclipticLongitude: Angle, principalHalfWidth: Angle = MoonPhaseName.defaultPrincipalHalfWidth) {
		assert(excessEclipticLongitude.radians.isFinite, "Excess ecliptic longitude must be finite")
		assert(principalHalfWidth.degrees >= 0 && principalHalfWidth.degrees <= 45, "Half-width must be in the closed interval [0°, 45°]")
		let excess = excessEclipticLongitude.normalized().radians
		// The nearest principal phase, from 0 for new Moon to 4 for the next new Moon, and the
		// excess's distance from it. Reducing an angle to a turn and converting it between
		// degrees and radians round it by a few units in the last place, which would take an
		// excess given at the end of a principal phase just outside it, so the ends are widened
		// by the roundoff tolerance.
		let nearest = (excess / halfPi).rounded()
		if abs(excess - nearest * halfPi) <= principalHalfWidth.radians + Self.roundoffTolerance {
			self = [MoonPhaseName.newMoon, .firstQuarter, .fullMoon, .lastQuarter][Int(nearest) % 4]
		} else {
			self = [MoonPhaseName.waxingCrescent, .waxingGibbous, .waningGibbous, .waningCrescent][Int(excess / halfPi) % 4]
		}
	}

	/// Whether the phase is between new Moon and full Moon: a waxing crescent, first quarter,
	/// or waxing gibbous.
	///
	/// New Moon and full Moon are neither waxing nor waning. For whether the Moon's illuminated
	/// fraction is growing at any instant, see ``Illumination/isEastOfSun``.
	public var isWaxing: Bool {
		switch self {
		case .waxingCrescent, .firstQuarter, .waxingGibbous: true
		default: false
		}
	}

	/// Whether the phase is between full Moon and new Moon: a waning gibbous, last quarter, or
	/// waning crescent.
	///
	/// New Moon and full Moon are neither waxing nor waning.
	public var isWaning: Bool {
		switch self {
		case .waningGibbous, .lastQuarter, .waningCrescent: true
		default: false
		}
	}
}
