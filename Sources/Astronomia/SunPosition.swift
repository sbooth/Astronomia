//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// The position of the sun relative to a particular geographic location and time.
public struct SunPosition: Hashable {
	/// The observation location.
	let observationLocation: ObservationLocation
	/// The observation date and time.
	let observationDate: Date
	/// The true altitude in degrees relative to the horizon.
	let altitude: Double
	/// The azimuth from true north in degrees.
	let azimuth: Double
}

extension SunPosition {
	/// True if the altitude is above -0.8333°.
	/// - note: -0.8333° accounts for -0.5667° of standard atmospheric refraction at the horizon plus -0.2666° for the sun's semidiameter
	public var isDay: Bool {
		altitude > -0.8333
	}
	/// True if the altitude is at or below -0.8333° and above -6°.
	/// - note: -0.8333° accounts for -0.5667° of standard atmospheric refraction at the horizon plus -0.2666° for the sun's semidiameter
	public var isCivilTwilight: Bool {
		altitude <= -0.8333 && altitude > -6
	}
	/// True if the altitude is at or below -6° and above -12°.
	public var isNauticalTwilight: Bool {
		altitude <= -6 && altitude > -12
	}
	/// True if the altitude is at or below -12° and above -18°.
	public var isAstronomicalTwilight: Bool {
		altitude <= -12 && altitude > -18
	}
	/// True if the altitude is at or below -18°.
	public var isNight: Bool {
		altitude <= -18
	}
}

extension SunPosition {
	/// Calculates and initializes the Sun's position as observed  from `location` on `date` .
	/// - parameter location: The observation location.
	/// - parameter date: The observation date.
	/// - parameter correctForAberration: Whether to correct for aberration.
	/// - parameter correctForRefraction: Whether to correct for atmospheric refraction.
	/// - returns: The Sun's position.
	public init(observedFrom location: ObservationLocation, on date: Date, correctForAberration: Bool = true, correctForRefraction: Bool = true) throws {
		let observer = location.toAstroObserver()
		var time = date.toAstroTime()
		let aberration: astro_aberration_t = correctForAberration ? ABERRATION : NO_ABERRATION

		let sun_equator_of_date = Astronomy_Equator(BODY_SUN, &time, observer, EQUATOR_OF_DATE, aberration)
		guard sun_equator_of_date.status == ASTRO_SUCCESS else {
			throw AstronomyEngineError(status: sun_equator_of_date.status)
		}

		let refraction: astro_refraction_t = correctForRefraction ? REFRACTION_NORMAL : REFRACTION_NONE
		let sun_horizontal_coordinates = Astronomy_Horizon(&time, observer, sun_equator_of_date.ra, sun_equator_of_date.dec, refraction)

		observationLocation = location
		observationDate = date
		altitude = sun_horizontal_coordinates.altitude
		azimuth = sun_horizontal_coordinates.azimuth
	}
}
