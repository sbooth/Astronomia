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
/// give. Without a barometer, ``init(height:temperature:relativeHumidity:wavelength:)``
/// estimates it from the site's height and temperature, and ``standard`` and
/// ``standard(height:relativeHumidity:wavelength:)`` describe the International Standard
/// Atmosphere at sea level and at a height.
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
	///   - relativeHumidity: The relative humidity, from 0 to 1. In the optical and infrared,
	///     humid air refracts up to 0.5% less than dry air; in the radio, up to half again as
	///     much.
	///   - wavelength: The wavelength observed: 0.55 µm, the center of the visual band, by
	///     default.
	/// - Throws:
	///   - ``AtmosphericConditionsError/nonFiniteValue`` if a value is NaN or infinite.
	///   - ``AtmosphericConditionsError/invalidPressure`` if the pressure is negative or
	///     greater than 10,000 hPa.
	///   - ``AtmosphericConditionsError/invalidTemperature`` if the temperature is below
	///     -150 °C or above 200 °C.
	///   - ``AtmosphericConditionsError/invalidRelativeHumidity`` if the relative humidity is
	///     outside the closed interval [0, 1].
	///   - ``AtmosphericConditionsError/invalidVaporPressure`` if the relative humidity is
	///     above 0 and the pressure is at or below the saturation vapor pressure of water at
	///     the temperature, as at 6 hPa and 10 °C, where water would boil.
	///   - ``AtmosphericConditionsError/invalidWavelength`` if the wavelength is shorter than
	///     0.1 µm or longer than 1 m.
	public init(pressure: Pressure, temperature: Temperature, relativeHumidity: Double, wavelength: Distance = .micrometers(0.55)) throws(AtmosphericConditionsError) {
		guard pressure.pascals.isFinite, temperature.kelvins.isFinite, relativeHumidity.isFinite, wavelength.astronomicalUnits.isFinite else {
			throw .nonFiniteValue
		}
		guard Self.pressureRange.contains(pressure.hectopascals) else {
			throw .invalidPressure
		}
		guard Self.temperatureRange.contains(temperature.degreesCelsius) else {
			throw .invalidTemperature
		}
		guard (0 ... 1).contains(relativeHumidity) else {
			throw .invalidRelativeHumidity
		}
		guard Self.wavelengthRange.contains(wavelength.micrometers) else {
			throw .invalidWavelength
		}
		// Humid air needs a pressure above the saturation vapor pressure; nearer it, the
		// vapor-pressure model diverges.
		guard relativeHumidity == 0 || pressure.hectopascals == 0 || Self.saturationVaporPressure(pressure: pressure.hectopascals, temperature: temperature.degreesCelsius) < pressure.hectopascals else {
			throw .invalidVaporPressure
		}
		self.init(uncheckedPressure: pressure, temperature: temperature, relativeHumidity: relativeHumidity, wavelength: wavelength)
	}

	/// Creates a description of the atmosphere at a site, with the pressure estimated from
	/// the site's height and temperature.
	///
	/// The pressure is that of an atmosphere at the site's temperature throughout, as ERFA
	/// suggests: 1013.25 hPa × exp(-h / (29.3 m/K × T)) for a height h and temperature T. At
	/// 4,205 m and 0 °C it is 599 hPa. A barometer's reading is better: the pressure at a site
	/// varies with the weather by a few percent, which changes the refraction by as much.
	///
	/// ```swift
	/// let conditions = try AtmosphericConditions(
	/// 	height: .meters(4205),
	/// 	temperature: .degreesCelsius(0),
	/// 	relativeHumidity: 0.2)
	/// ```
	///
	/// - Parameters:
	///   - height: The height of the site above sea level. The height above the ellipsoid of
	///     an ``Observer`` differs from it by the geoid's height, up to about 100 m, which
	///     changes the pressure by about 1%.
	///   - temperature: The air temperature at the site.
	///   - relativeHumidity: The relative humidity, from 0 to 1. In the optical and infrared,
	///     humid air refracts up to 0.5% less than dry air; in the radio, up to half again as
	///     much.
	///   - wavelength: The wavelength observed: 0.55 µm, the center of the visual band, by
	///     default.
	/// - Throws: An ``AtmosphericConditionsError``, as
	///   ``init(pressure:temperature:relativeHumidity:wavelength:)`` does for the estimated
	///   pressure: ``AtmosphericConditionsError/invalidPressure`` for a height so far below
	///   sea level that the pressure would be greater than 10,000 hPa, and
	///   ``AtmosphericConditionsError/invalidVaporPressure`` for humid air so high that the
	///   pressure would be at or below the saturation vapor pressure.
	public init(height: Distance, temperature: Temperature, relativeHumidity: Double, wavelength: Distance = .micrometers(0.55)) throws(AtmosphericConditionsError) {
		guard height.astronomicalUnits.isFinite, temperature.kelvins.isFinite else {
			throw .nonFiniteValue
		}
		guard Self.temperatureRange.contains(temperature.degreesCelsius) else {
			throw .invalidTemperature
		}
		let pressure = Pressure.standardAtmosphere.hectopascals * Math.exp(-height.meters / (Self.scaleHeightPerKelvin * temperature.kelvins))
		try self.init(pressure: .hectopascals(pressure), temperature: temperature, relativeHumidity: relativeHumidity, wavelength: wavelength)
	}

	/// Creates a description of the atmosphere at a site from values already known to be
	/// valid.
	///
	/// - Precondition: The values satisfy the requirements of the public initializer.
	init(uncheckedPressure pressure: Pressure, temperature: Temperature, relativeHumidity: Double, wavelength: Distance) {
		assert(pressure.pascals.isFinite && temperature.kelvins.isFinite && relativeHumidity.isFinite && wavelength.astronomicalUnits.isFinite, "Non-finite value")
		assert(Self.pressureRange.contains(pressure.hectopascals), "Invalid pressure")
		assert(Self.temperatureRange.contains(temperature.degreesCelsius), "Invalid temperature")
		assert((0 ... 1).contains(relativeHumidity), "Invalid relative humidity")
		assert(Self.wavelengthRange.contains(wavelength.micrometers), "Invalid wavelength")
		assert(relativeHumidity == 0 || pressure.hectopascals == 0 || Self.saturationVaporPressure(pressure: pressure.hectopascals, temperature: temperature.degreesCelsius) < pressure.hectopascals, "Invalid vapor pressure")
		self.pressure = pressure
		self.temperature = temperature
		self.relativeHumidity = relativeHumidity
		self.wavelength = wavelength
	}
}

extension AtmosphericConditions {
	/// The International Standard Atmosphere at sea level: 1013.25 hPa, 15 °C, and dry air,
	/// observed at 0.55 µm.
	///
	/// Its refraction is 57.2" at an altitude of 45°. Humid air refracts visible light slightly
	/// less, by 0.2% at a relative humidity of 80%.
	public static let standard = AtmosphericConditions(uncheckedPressure: .standardAtmosphere, temperature: .kelvins(standardSeaLevelTemperature), relativeHumidity: 0, wavelength: .micrometers(0.55))

	/// Returns the International Standard Atmosphere at a height, for a site without a
	/// barometer or thermometer.
	///
	/// The temperature falls from 15 °C at sea level by 6.5 K per kilometer, and the pressure
	/// with it as p = 1013.25 hPa × (T / 288.15 K)^5.255876, as in the troposphere of the ISA
	/// (ISO 2533:1975). At 4,205 m it gives -12.3 °C and 600 hPa. A site's actual pressure
	/// differs with the weather by a few percent, and its temperature by tens of kelvins, which
	/// change the refraction by as much.
	///
	/// ```swift
	/// let conditions = try AtmosphericConditions.standard(height: .meters(4205))
	/// ```
	///
	/// - Parameters:
	///   - height: The height of the site above sea level, from -2 km to 11 km, the
	///     tropopause. The height above the ellipsoid of an ``Observer`` differs from it by the
	///     geoid's height, up to about 100 m, which changes the pressure by about 1%.
	///   - relativeHumidity: The relative humidity, from 0 to 1: 0, the dry air of the ISA, by
	///     default. Humid air refracts up to 0.5% less in the optical and infrared, and up to
	///     half again as much in the radio.
	///   - wavelength: The wavelength observed: 0.55 µm, the center of the visual band, by
	///     default.
	/// - Returns: The atmosphere at `height`.
	/// - Throws:
	///   - ``AtmosphericConditionsError/nonFiniteValue`` if a value is NaN or infinite.
	///   - ``AtmosphericConditionsError/invalidHeight`` if the height is below -2 km or above
	///     11 km.
	///   - ``AtmosphericConditionsError/invalidRelativeHumidity`` if the relative humidity is
	///     outside the closed interval [0, 1].
	///   - ``AtmosphericConditionsError/invalidWavelength`` if the wavelength is shorter than
	///     0.1 µm or longer than 1 m.
	public static func standard(height: Distance, relativeHumidity: Double = 0, wavelength: Distance = .micrometers(0.55)) throws(AtmosphericConditionsError) -> AtmosphericConditions {
		guard height.astronomicalUnits.isFinite else {
			throw .nonFiniteValue
		}
		// A micrometer's allowance for the rounding of a height in meters stored in au
		guard (standardMinimumHeight - 1e-6 ... standardMaximumHeight + 1e-6).contains(height.meters) else {
			throw .invalidHeight
		}
		let temperature = standardSeaLevelTemperature - standardLapseRate * height.meters
		let pressure = Pressure.standardAtmosphere.pascals * Math.pow(temperature / standardSeaLevelTemperature, standardPressureExponent)
		return try AtmosphericConditions(pressure: .pascals(pressure), temperature: .kelvins(temperature), relativeHumidity: relativeHumidity, wavelength: wavelength)
	}

	/// The accepted pressures, in hPa: 0 to 10,000 hPa, with an allowance for rounding in a
	/// conversion from another unit.
	static let pressureRange: ClosedRange<Double> = 0 ... 10_000 * (1 + 1e-12)

	/// The accepted temperatures, in °C: -150 °C to 200 °C, with an allowance for rounding in
	/// a conversion from another unit.
	static let temperatureRange: ClosedRange<Double> = (-150 - 1e-9) ... (200 + 1e-9)

	/// The accepted wavelengths, in µm: 0.1 µm to 1 m, with an allowance for rounding in a
	/// conversion through astronomical units.
	static let wavelengthRange: ClosedRange<Double> = (0.1 * (1 - 1e-12)) ... (1e6 * (1 + 1e-12))

	/// The longest optical and infrared wavelength, in µm: 100 µm, as in `eraRefco`, with an
	/// allowance for rounding, so that 100 µm in any unit is optical.
	static let longestOpticalWavelength: Double = 100 * (1 + 1e-12)

	/// The scale height of an atmosphere per kelvin of its temperature, R / (M g), in meters,
	/// as in ERFA's estimate of the pressure at a site.
	static let scaleHeightPerKelvin: Double = 29.3

	/// The temperature of the International Standard Atmosphere at sea level, in kelvins.
	static let standardSeaLevelTemperature: Double = 288.15

	/// The fall of temperature with height in the troposphere of the International Standard
	/// Atmosphere, in kelvins per meter.
	static let standardLapseRate: Double = 0.0065

	/// The exponent of the pressure in the troposphere of the International Standard
	/// Atmosphere, g₀ M / (R* L), with g₀ = 9.80665 m/s², M = 0.0289644 kg/mol,
	/// R* = 8.31432 J/(mol K), and L = 0.0065 K/m.
	static let standardPressureExponent: Double = 5.255_876

	/// The lowest height of the International Standard Atmosphere, in meters.
	static let standardMinimumHeight: Double = -2_000

	/// The height of the tropopause of the International Standard Atmosphere, above which the
	/// temperature no longer falls, in meters.
	static let standardMaximumHeight: Double = 11_000
}

extension AtmosphericConditions {
	/// Returns the saturation vapor pressure of water in air, in hPa, from Gill (1982) as in
	/// `eraRefco` of ERFA, with the enhancement for air at a pressure.
	///
	/// - Parameters:
	///   - pressure: The air pressure, in hPa.
	///   - temperature: The temperature, in °C.
	static func saturationVaporPressure(pressure: Double, temperature: Double) -> Double {
		let t = temperature
		return Math.pow(10, (0.7859 + 0.03477 * t) / (1 + 0.00412 * t)) * (1 + pressure * (4.5e-6 + 6e-10 * t * t))
	}

	/// The constants A and B of the refraction A tan z + B tan³ z, in radians, following
	/// `eraRefco` of ERFA.
	///
	/// The refractive index of the air follows Hohenkerk and Sinclair (1985) in the optical and
	/// infrared and Rueger (2002) in the radio; the decrease of the index with height follows
	/// Stone (1996), and A and B follow Green (1987).
	var refractionConstants: (a: Double, b: Double) {
		let isOptical = wavelength.micrometers <= Self.longestOpticalWavelength
		let p = pressure.hectopascals
		let t = temperature.degreesCelsius
		let r = relativeHumidity
		let w = wavelength.micrometers

		// The water vapor pressure at the site, in hPa, from Crane (1976), which with the
		// saturation vapor pressure below the pressure, as validated, is at most the pressure
		let waterVaporPressure: Double
		if p > 0, r > 0 {
			let saturation = Self.saturationVaporPressure(pressure: p, temperature: t)
			waterVaporPressure = r * saturation / (1 - (1 - r) * saturation / p)
		} else {
			waterVaporPressure = 0
		}

		// The refractive index minus 1 at the site
		let tk = t + Temperature.kelvinsAtZeroCelsius
		let gamma: Double
		if isOptical {
			let w2 = w * w
			gamma = ((77.53484e-6 + (4.391_08e-7 + 3.666e-9 / w2) / w2) * p - 11.2684e-6 * waterVaporPressure) / tk
		} else {
			gamma = (77.6890e-6 * p - (6.3938e-6 - 0.375463 / tk) * waterVaporPressure) / tk
		}

		// Stone's beta, with ERFA's empirical adjustment in the radio
		var beta = 4.4474e-6 * tk
		if !isOptical {
			beta -= 0.0074 * waterVaporPressure * beta
		}
		return (gamma * (1 - beta), -gamma * (beta - gamma / 2))
	}
}
