//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// A phase of the Moon.
public enum MoonPhase {
	/// A New Moon.
	///
	/// The New Moon corresponds to an ecliptic phase angle less than 45 ° or equal to 360 °.
	case new
	/// Waxing crescent.
	///
	/// A waxing crescent moon corresponds to an ecliptic phase angle greater than or equal to 45 ° and less than 90 °.
	case waxingCrescent
	/// First Quarter.
	///
	/// The First Quarter corresponds to an ecliptic phase angle greater than or equal to 90 ° and less than 135 °.
	case firstQuarter
	/// Waxing gibbous.
	///
	/// A waxing gibbous moon corresponds to an ecliptic phase angle greater than or equal to 135 ° and less than 180 °.
	case waxingGibbous
	/// Full Moon.
	///
	/// The Full Moon corresponds to an ecliptic phase angle greater than or equal to 180 ° and less than 225 °.
	case full
	/// Waning gibbous.
	///
	/// A waning gibbous moon corresponds to an ecliptic phase angle greater than or equal to 225 ° and less than 270 °.
	case waningGibbous
	/// Third Quarter.
	///
	/// The Third Quarter corresponds to an ecliptic phase angle greater than or equal to 270 ° and less than 315 °.
	case thirdQuarter
	/// Waning crescent.
	///
	/// A waning crescent moon corresponds to an ecliptic phase angle greater than or equal to 315 ° and less than 360 °.
	case waningCrescent
}

/// The position of the Moon relative to a particular geographic location and time.
public struct MoonPosition: Hashable {
	/// The observation location.
	let observationLocation: ObservationLocation
	/// The observation date and time.
	let observationDate: Date
	/// The true altitude in degrees relative to the horizon.
	public let altitude: Double
	/// The azimuth from true North in degrees.
	public let azimuth: Double
	/// The ecliiptic phase angle in degrees.
	public let phaseAngle: Double
	/// The illuminated fraction.
	public let illuminatedFraction: Double
	/// The parallactic angle `q` in degrees.
	public let parallacticAngle: Double
	/// The position angle `χ` of the midpoint of the illuminated limb in degrees.
	/// - note: The angle is reckoned eastward from the north point of the disk.
	public let positionAngle: Double
}

extension MoonPosition {
	/// The most-recently achieved phase of the Moon.
	public var phase: MoonPhase {
		precondition(phaseAngle >= 0)
		precondition(phaseAngle < 360)
		switch Int(floor(phaseAngle / (360 / 8))) {
		case 0:
			return .new
		case 1:
			return .waxingCrescent
		case 2:
			return .firstQuarter
		case 3:
			return .waxingGibbous
		case 4:
			return .full
		case 5:
			return .waningGibbous
		case 6:
			return .thirdQuarter
		case 7:
			return .waningCrescent
		default:
			preconditionFailure("Invalid moon ecliptic phase angle")
		}
	}
}

extension MoonPosition {
	/// `true` if the phase angle is less than 180.
	public var isWaxing: Bool {
		phaseAngle < 180
	}
	/// `true` if the phase angle is greater than 180.
	public var isWaning: Bool {
		phaseAngle > 180
	}
}

extension MoonPosition {
	/// The zenith angle of the midpoint of the illuminated limb in degrees.
	public var zenithAngle: Double {
		positionAngle - parallacticAngle
	}
}

extension MoonPosition {
	/// True if the altitude is above -0.825°.
	/// - note: -0.825° accounts for -0.5667° of standard atmospheric refraction at the horizon plus -0.2583° for the moon's average semidiameter
	/// - note: This is not the most accurate way to test for moonrise since the moon's actual semidiameter is not constant.
	public var risen: Bool {
		altitude > -0.825
	}
}

extension MoonPosition {
	/// Calculates and initializes the Moon's position as observed from `location` on `date` .
	/// - parameter location: The observation location.
	/// - parameter date: The observation date.
	/// - parameter correctForAberration: Whether to correct for aberration.
	/// - parameter correctForRefraction: Whether to correct for atmospheric refraction.
	public init(observedFrom location: ObservationLocation, on date: Date, correctForAberration: Bool = true, correctForRefraction: Bool = true) throws {
		var time = date.toAstroTime()

		let moon_phase = Astronomy_MoonPhase(time)
		guard moon_phase.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: moon_phase.status)
		}

		precondition(moon_phase.angle >= 0)
		precondition(moon_phase.angle < 360)

		let moon_illumination = Astronomy_Illumination(BODY_MOON, time)
		guard moon_illumination.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: moon_illumination.status)
		}

		let observer = location.toAstroObserver()
		let aberration: astro_aberration_t = correctForAberration ? ABERRATION : NO_ABERRATION

		let moon_equator_of_date = Astronomy_Equator(BODY_MOON, &time, observer, EQUATOR_OF_DATE, aberration)
		guard moon_equator_of_date.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: moon_equator_of_date.status)
		}

		let refraction: astro_refraction_t = correctForRefraction ? REFRACTION_NORMAL : REFRACTION_NONE

		let moon_horizontal_coordinates = Astronomy_Horizon(&time, observer, moon_equator_of_date.ra, moon_equator_of_date.dec, refraction)

//		let moon_parallactic_angle = Astronomy_ParallacticAngle(BODY_MOON, time, observer, aberration)
//		guard moon_parallactic_angle.status == ASTRO_SUCCESS else {
//			throw AstronomyEngineError(status: moon_parallactic_angle.status)
//		}

		// Parallactic angle (q)
		// Meeus equation 14.1 (p. 98)
		let moon_hour_angle = Astronomy_HourAngle(BODY_MOON, &time, observer)
		guard moon_hour_angle.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: moon_hour_angle.status)
		}

		precondition(moon_hour_angle.value >= 0)
		precondition(moon_hour_angle.value < 24)

		let H = moon_hour_angle.value.hoursToRadians()
		let φ = observer.latitude.degreesToRadians()
		let δ = moon_equator_of_date.dec.degreesToRadians()
		let α = moon_equator_of_date.ra.hoursToRadians()

		let q = atan2(sin(H), tan(φ) * cos(δ) - sin(δ) * cos(H))

		let moon_parallactic_angle = q.radiansToDegrees()

//		let moon_position_angle = Astronomy_BrightLimbAngle(BODY_MOON, time, observer, aberration)
//		guard moon_position_angle.status == ASTRO_SUCCESS else {
//			throw AstronomyEngineError(status: moon_position_angle.status)
//		}

		// Position Angle of the Moon's bright limb (χ)
		// Meeus equation 48.5 (p. 346)
		let sun_equator_of_date = Astronomy_Equator(BODY_SUN, &time, observer, EQUATOR_OF_DATE, aberration)
		guard sun_equator_of_date.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: sun_equator_of_date.status)
		}

		let δ0 = sun_equator_of_date.dec.degreesToRadians()
		let α0 = sun_equator_of_date.ra.hoursToRadians()

		let χ = atan2(cos(δ0) * sin(α0 - α), sin(δ0) * cos(δ) - cos(δ0) * sin(δ) * cos(α0 - α))

		let moon_position_angle = χ.radiansToDegrees().normalizedDegrees()

		observationLocation = location
		observationDate = date
		altitude = moon_horizontal_coordinates.altitude
		azimuth = moon_horizontal_coordinates.azimuth
		phaseAngle = moon_phase.angle
		illuminatedFraction = moon_illumination.phase_fraction
		parallacticAngle = moon_parallactic_angle
//		parallacticAngle = moon_parallactic_angle.angle
		positionAngle = moon_position_angle
//		positionAngle = moon_position_angle.angle
	}
}
