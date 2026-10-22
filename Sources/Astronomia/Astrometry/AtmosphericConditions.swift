//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The atmosphere at a site and the wavelength observed, from which the refraction of an
/// ``ObservedPlace`` is found.
///
/// Refraction raises a target toward the zenith by about 1′ at an altitude of 45°, and by more
/// nearer the horizon. It follows the model of `eraRefco` of ERFA: the refraction is
/// A tan z + B tan³ z for a zenith distance z, with A and B from the refractive index of the
/// air at the site and a model of its decrease with height. Wavelengths up to 100 µm are
/// optical and infrared, where humidity matters little; longer ones are radio, where it
/// matters much more.
///
/// ```swift
/// let conditions = try AtmosphericConditions(
/// 	pressure: .hectopascals(1013.25),
/// 	temperature: .degreesCelsius(10),
/// 	relativeHumidity: 0.5)
/// let place = try sky.observedPlace(of: sky.apparentPlace(of: .moon), conditions: conditions)
/// ```
///
/// The pressure is the one at the site, not the reduction to sea level that weather reports
/// give. Without a barometer, it can be estimated from the site's height h and temperature T
/// as 1013.25 hPa × exp(-h / (29.3 m/K × T)).
///
/// - Note: Against ray tracing through model atmospheres, the model is within 0.06" in the
///   optical and infrared and 0.32" in the radio to a zenith distance of 75°, and 0.6" at 80°.
///   Nearer the horizon the refraction depends on the layers of air along the line of sight,
///   which no model of the conditions at the site can predict. Below an altitude of about
///   2.9°, the model's refraction is held at its value there, about 0.19° at sea level, though
///   the refraction at the horizon is typically about 0.57°.
public struct AtmosphericConditions: Hashable, Sendable {
	/// The air pressure at the site.
	public let pressure: Pressure
	/// The air temperature at the site.
	public let temperature: Temperature
	/// The relative humidity, from 0 to 1.
	public let relativeHumidity: Double
	/// The wavelength observed.
	public let wavelength: Distance

	/// Creates a description of the atmosphere at a site.
	///
	/// - Parameters:
	///   - pressure: The air pressure at the site. A pressure of zero gives no refraction.
	///   - temperature: The air temperature at the site.
	///   - relativeHumidity: The relative humidity, from 0 to 1.
	///   - wavelength: The wavelength observed: 0.55 µm, the center of the visual band, by
	///     default.
	/// - Throws:
	///   - ``AtmosphericConditionsError/nonFiniteValue`` if a value is NaN or infinite.
	///   - ``AtmosphericConditionsError/invalidPressure`` if the pressure is negative or
	///     greater than 10,000 hPa.
	///   - ``AtmosphericConditionsError/invalidTemperature`` if the temperature is below
	///     -150 °C or above 200 °C.
	///   - ``AtmosphericConditionsError/invalidRelativeHumidity`` if the relative humidity is
	///     outside [0, 1].
	///   - ``AtmosphericConditionsError/invalidWavelength`` if the wavelength is shorter than
	///     0.1 µm or longer than 1 m.
	public init(pressure: Pressure, temperature: Temperature, relativeHumidity: Double, wavelength: Distance = .micrometers(0.55)) throws(AtmosphericConditionsError) {
		guard pressure.pascals.isFinite, temperature.kelvins.isFinite, relativeHumidity.isFinite, wavelength.astronomicalUnits.isFinite else {
			throw .nonFiniteValue
		}
		guard (0 ... 10_000).contains(pressure.hectopascals) else {
			throw .invalidPressure
		}
		guard (-150 ... 200).contains(temperature.degreesCelsius) else {
			throw .invalidTemperature
		}
		guard (0 ... 1).contains(relativeHumidity) else {
			throw .invalidRelativeHumidity
		}
		guard (0.1 ... 1e6).contains(wavelength.micrometers) else {
			throw .invalidWavelength
		}
		self.pressure = pressure
		self.temperature = temperature
		self.relativeHumidity = relativeHumidity
		self.wavelength = wavelength
	}
}

extension AtmosphericConditions {
	/// The constants A and B of the refraction A tan z + B tan³ z, in radians, following
	/// `eraRefco` of ERFA.
	///
	/// The refractive index of the air follows Hohenkerk and Sinclair (1985) in the optical and
	/// infrared and Rueger (2002) in the radio; the decrease of the index with height follows
	/// Stone (1996), and A and B follow Green (1987).
	var refractionConstants: (a: Double, b: Double) {
		let isOptical = wavelength.micrometers <= 100
		let p = pressure.hectopascals
		let t = temperature.degreesCelsius
		let r = relativeHumidity
		let w = wavelength.micrometers

		// The water vapour pressure at the site, in hPa
		let waterVapourPressure: Double
		if p > 0 {
			let saturation = Math.pow(10, (0.7859 + 0.03477 * t) / (1 + 0.00412 * t)) * (1 + p * (4.5e-6 + 6e-10 * t * t))
			waterVapourPressure = r * saturation / (1 - (1 - r) * saturation / p)
		} else {
			waterVapourPressure = 0
		}

		// The refractive index minus 1 at the site
		let tk = t + Temperature.kelvinsAtZeroCelsius
		let gamma: Double
		if isOptical {
			let w2 = w * w
			gamma = ((77.53484e-6 + (4.391_08e-7 + 3.666e-9 / w2) / w2) * p - 11.2684e-6 * waterVapourPressure) / tk
		} else {
			gamma = (77.6890e-6 * p - (6.3938e-6 - 0.375463 / tk) * waterVapourPressure) / tk
		}

		// Stone's beta, with ERFA's empirical adjustment in the radio
		var beta = 4.4474e-6 * tk
		if !isOptical {
			beta -= 0.0074 * waterVapourPressure * beta
		}
		return (gamma * (1 - beta), -gamma * (beta - gamma / 2))
	}
}
