//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when describing the atmosphere at a site.
public enum AtmosphericConditionsError: Error, Hashable, Sendable {
	/// A value is NaN or infinite.
	case nonFiniteValue
	/// The pressure is negative or greater than 10,000 hPa.
	case invalidPressure
	/// The temperature is below -150 °C or above 200 °C.
	case invalidTemperature
	/// The relative humidity is outside the closed interval [0, 1].
	case invalidRelativeHumidity
	/// The wavelength is shorter than 0.1 µm or longer than 1 m.
	case invalidWavelength
	/// The relative humidity is above 0 and the pressure is at or below the saturation vapour
	/// pressure of water at the temperature, where water would boil.
	case invalidVapourPressure
	/// The height is below -2 km or above 11 km, outside the troposphere of the International
	/// Standard Atmosphere.
	case invalidHeight
}
