//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

@Suite struct ObservedTests {
	/// Microarcseconds per radian.
	static let uas = microarcsecondsPerRadian

	/// The Earth orientation of the ERFA fixtures: UT1 = TT - 69.2 s and a constant polar motion
	/// of 0.12" and 0.34" from 1998 to 2050.
	static let polarMotion: EarthOrientation = {
		let motion = PolarMotion(x: Angle(arcseconds: 0.12), y: Angle(arcseconds: 0.34))
		let entries = [2_451_000, 2_470_000].map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: 0, polarMotion: motion) }
		return EarthOrientation(table: EarthOrientationTable(entries: entries), ut1: UT1.Context(deltaT: DeltaTFunction.constant(69.2)))
	}()

	static func conditions(_ index: Int) throws -> AtmosphericConditions? {
		try fixtureConditions[index].map { try AtmosphericConditions(pressure: .hectopascals($0.pressure), temperature: .degreesCelsius($0.temperature), relativeHumidity: $0.relativeHumidity, wavelength: .micrometers($0.wavelength)) }
	}

	/// Returns the difference of two angles, in radians, reduced to [-π, π), in µas.
	static func difference(_ a: Double, _ b: Double) -> Double {
		var d = (a - b).truncatingRemainder(dividingBy: twoPi)
		if d >= .pi { d -= twoPi } else if d < -.pi { d += twoPi }
		return d * uas
	}

	/// Returns observations from the fixture sites, one per site and date.
	final class Observations {
		let earthOrientation: EarthOrientation
		var cache: [String: Observation<BuiltInEphemeris>] = [:]

		init(earthOrientation: EarthOrientation) {
			self.earthOrientation = earthOrientation
		}

		func observation(site: Int, julianDate: Double) throws -> Observation<BuiltInEphemeris> {
			let key = "\(site) \(julianDate)"
			if let observation = cache[key] { return observation }
			let observation = try TopocentricTests.site(site).observation(at: Instant<TT>(try JulianDate(julianDate: julianDate)), earthOrientation: earthOrientation)
			cache[key] = observation
			return observation
		}
	}

	@Test func refractionConstantsMatchERFA() throws {
		for row in erfaRefractionConstants {
			let conditions = try AtmosphericConditions(pressure: .hectopascals(row.pressure), temperature: .degreesCelsius(row.temperature), relativeHumidity: row.relativeHumidity, wavelength: .micrometers(row.wavelength))
			let (a, b) = conditions.refractionConstants
			#expect(abs(a - row.a) <= 1e-15 * abs(row.a), "\(row)")
			#expect(abs(b - row.b) <= 1e-15 * abs(row.b), "\(row)")
		}
	}

	@Test func starPlacesMatchERFA() throws {
		// Through atioq, with polar motion, without refraction and with it for optical and
		// radio conditions, for stars above and below the horizon
		let observations = Observations(earthOrientation: Self.polarMotion)
		for row in erfaObservedStarPlaces {
			let observation = try observations.observation(site: row.site, julianDate: row.julianDate)
			let place = try observation.observedPlace(of: observation.apparentPlace(of: StarTests.star(row.star)), conditions: Self.conditions(row.conditions))
			let comment = Comment(rawValue: "star \(row.star) from \(fixtureSites[row.site].name) at \(row.julianDate) under \(row.conditions)")
			#expect(abs(Self.difference(place.azimuth.radians, row.azimuth) * Math.sin(row.zenithDistance)) <= 2, comment)
			#expect(abs(Self.difference(place.zenithDistance.radians, row.zenithDistance)) <= 2, comment)
			#expect(abs(Self.difference(place.hourAngle.radians, row.hourAngle) * Math.cos(row.declination)) <= 2, comment)
			#expect(abs(Self.difference(place.declination.radians, row.declination)) <= 2, comment)
			#expect((0 ..< twoPi).contains(place.azimuth.radians))
			#expect(place.hourAngle.radians > -.pi && place.hourAngle.radians <= .pi)
		}
	}

	@Test func bodiesMatchSkyfield() throws {
		// Skyfield's apparent places turned to the horizon, which differ by the two libraries'
		// Earth rotation, within 24 µas of each other by 2049
		let observations = Observations(earthOrientation: TopocentricTests.earthOrientation)
		for row in skyfieldObservedPlaces {
			let observation = try observations.observation(site: row.site, julianDate: row.julianDate)
			let apparent = ApparentPlace<ICRS>(position: Position(TopocentricTests.vector(row.apparent)), lightTime: .zero, instant: observation.instant)
			let place = try observation.observedPlace(of: apparent)
			let comment = Comment(rawValue: "\(row.body) from \(fixtureSites[row.site].name) at \(row.julianDate)")
			#expect(abs(Self.difference(place.azimuth.radians, row.azimuth) * Math.cos(row.altitude)) <= 30, comment)
			#expect(abs(Self.difference(place.altitude.radians, row.altitude)) <= 30, comment)
			#expect(abs(Self.difference(place.hourAngle.radians, row.hourAngle) * Math.cos(row.declination)) <= 30, comment)
			#expect(abs(Self.difference(place.declination.radians, row.declination)) <= 30, comment)
			#expect(place.distance == Distance(astronomicalUnits: TopocentricTests.vector(row.apparent).length))
			#expect(place.instant == observation.instant)
		}
	}

	@Test func refraction() throws {
		// ERFA's example conditions, at the horizon of a site on the equator at longitude 0
		let conditions = try AtmosphericConditions(pressure: .hectopascals(1005), temperature: .kelvins(280.15), relativeHumidity: 0.8, wavelength: .micrometers(0.574))
		let (a, b) = conditions.refractionConstants
		let horizon = Horizon(toITRS: .identity, latitude: 0, longitude: 0)
		let tt = Instant<TT>(try JulianDate(julianDate: 2_461_334.75))
		func place(zenithDistance: Double, refracted: Bool) -> ObservedPlace {
			// Toward the north, so the horizon's up is the ITRS x axis and north its z axis
			let direction = Vector3(Math.cos(zenithDistance), 0, Math.sin(zenithDistance))
			return horizon.observedPlace(of: direction, refraction: refracted ? (a, b) : nil, distance: .astronomicalUnits(1), instant: tt)
		}
		for degrees in stride(from: 0.0, through: 75, by: 5) {
			let z = Angle(degrees: degrees).radians
			let unrefracted = place(zenithDistance: z, refracted: false)
			#expect(abs(unrefracted.zenithDistance.radians - z) <= 1e-15)
			let observed = place(zenithDistance: z, refracted: true)
			// The refraction found is the model's at the observed zenith distance.
			let delta = z - observed.zenithDistance.radians
			let tanZ = Math.tan(observed.zenithDistance.radians)
			#expect(abs(delta - (a * tanZ + b * tanZ * tanZ * tanZ)) * arcsecondsPerRadian <= 0.005, "\(degrees)°")
			#expect(observed.azimuth == unrefracted.azimuth)
		}
		// ERFA's table: 58.18" at an observed zenith distance of 45°
		let z = Angle(degrees: 45).radians + Angle(arcseconds: 58.18).radians
		#expect(abs(Angle(degrees: 45).radians - place(zenithDistance: z, refracted: true).zenithDistance.radians) * arcsecondsPerRadian <= 0.01)
		// At the zenith, there is none.
		#expect(place(zenithDistance: 0, refracted: true).altitude == .degrees(90))
		// Below 2.9°, the refraction is held at about 0.19°, and stays bounded and finite below
		// the horizon, where it falls to nothing toward the nadir.
		for degrees in [88.0, 90, 95, 120, 170, 180] {
			let z = Angle(degrees: degrees).radians
			let observed = place(zenithDistance: z, refracted: true)
			let shift = Angle(radians: z - observed.zenithDistance.radians).degrees
			#expect(observed.altitude.radians.isFinite && observed.hourAngle.radians.isFinite && observed.declination.radians.isFinite)
			#expect(degrees > 120 ? abs(shift) < 0.001 : shift > 0.13 && shift < 0.19, "\(degrees)°")
		}
		// Zero pressure refracts nothing.
		let vacuum = try AtmosphericConditions(pressure: .pascals(0), temperature: .degreesCelsius(10), relativeHumidity: 0.5)
		#expect(vacuum.refractionConstants == (0, 0))
	}

	@Test func hourAngleAndDeclination() throws {
		// At a site on the equator at longitude 0, without polar motion, the hour angle and
		// declination are the ITRS longitude, negated, and latitude.
		let horizon = Horizon(toITRS: .identity, latitude: 0, longitude: 0)
		let tt = Instant<TT>(try JulianDate(julianDate: 2_461_334.75))
		for (longitude, latitude) in [(0.3, 0.2), (-2.0, -0.7), (3.0, 1.2)] {
			let direction = Vector3(Math.cos(latitude) * Math.cos(longitude), Math.cos(latitude) * Math.sin(longitude), Math.sin(latitude))
			let place = horizon.observedPlace(of: direction, refraction: nil, distance: .astronomicalUnits(1), instant: tt)
			#expect(abs(place.hourAngle.radians + longitude) <= 1e-15)
			#expect(abs(place.declination.radians - latitude) <= 1e-15)
		}
		// The meridian, east, and west: the zenith at hour angle 0, the east point at -90°
		let place = { (direction: Vector3) in horizon.observedPlace(of: direction, refraction: nil, distance: .astronomicalUnits(1), instant: tt) }
		#expect(place(Vector3(1, 0, 0)).altitude == .degrees(90))
		#expect(place(Vector3(0, 1, 0)).azimuth == .degrees(90))
		#expect(place(Vector3(0, 1, 0)).hourAngle == .degrees(-90))
		#expect(place(Vector3(0, -1, 0)).azimuth == .degrees(270))
		#expect(place(Vector3(0, 0, 1)).azimuth == .zero)
		// The lower meridian is at hour angle 180°, not -180°.
		#expect(place(Vector3(-1, 0, 0)).hourAngle == .degrees(180))
		#expect(place(Vector3(-1, 0, 1e-3)).hourAngle == .degrees(180))
		// Just west of north, the azimuth rounds to 0, not 360°.
		#expect(place(Vector3(0, -1e-16, 1)).azimuth == .zero)
		#expect(place(Vector3(0, -1e-3, 1)).azimuth.radians < twoPi)
	}

	@Test func placesFromTheObservation() throws {
		let tt = Instant<TT>(try JulianDate(julianDate: 2_461_334.75))
		let site = try TopocentricTests.site(1)
		let sky = try site.observation(at: tt)
		// The geocenter has no horizon.
		let geocentric = try Observer.geocenter.observation(at: tt)
		#expect(throws: ObserverError.noHorizon) { try geocentric.observedPlace(of: geocentric.apparentPlace(of: .moon)) }
		// A place from another instant, or the geocentric place of the Earth, isn't from the
		// observation.
		let later = try site.observation(at: Instant<TT>(try JulianDate(julianDate: 2_461_334.76)))
		#expect(throws: ObserverError.placeMismatch) { try sky.observedPlace(of: later.apparentPlace(of: .moon)) }
		#expect(throws: ObserverError.placeMismatch) { try sky.observedPlace(of: geocentric.apparentPlace(of: .earth)) }
		// The Earth's center is below the horizon by 90°, less the 0.12° between the geodetic
		// and geocentric verticals at 19.8° latitude, and is seen where it was 21 ms earlier,
		// some 600 m away along its orbit.
		let earth = try sky.observedPlace(of: sky.apparentPlace(of: .earth))
		#expect(abs(earth.altitude.degrees + 89.878) < 0.001)
		let radius = try #require(site.position).vector.length
		#expect(abs(earth.distance.astronomicalUnits - radius) * metersPerAstronomicalUnit < 700)

		// Places in frames of date use the observation's Earth orientation.
		let star = try StarTests.star(2)
		let observed = try site.observation(at: tt, earthOrientation: Self.polarMotion)
		#expect(try observed.apparentPlace(of: .mars, in: TrueEquatorOfDate.self) == observed.apparentPlace(of: .mars).converted(to: TrueEquatorOfDate.self, earthOrientation: Self.polarMotion))
		#expect(try observed.apparentPlace(of: star, in: CIRS.self) == observed.apparentPlace(of: star).converted(to: CIRS.self, earthOrientation: Self.polarMotion))
		#expect(try observed.apparentPlace(of: star, in: CIRS.self).position.frameEpoch == tt)
	}

	@Test func conditionsValidation() throws {
		let p = Pressure.hectopascals(1000)
		let t = Temperature.degreesCelsius(10)
		_ = try AtmosphericConditions(pressure: .hectopascals(10_000), temperature: .degreesCelsius(-150), relativeHumidity: 0, wavelength: .micrometers(0.1))
		_ = try AtmosphericConditions(pressure: .pascals(0), temperature: .degreesCelsius(200), relativeHumidity: 1, wavelength: .micrometers(1e6))
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(pressure: .pascals(.nan), temperature: t, relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(pressure: p, temperature: .kelvins(.infinity), relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: .nan) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .micrometers(.infinity)) }
		#expect(throws: AtmosphericConditionsError.invalidPressure) { try AtmosphericConditions(pressure: .pascals(-1), temperature: t, relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.invalidPressure) { try AtmosphericConditions(pressure: .hectopascals(10_000.1), temperature: t, relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.invalidTemperature) { try AtmosphericConditions(pressure: p, temperature: .degreesCelsius(-150.1), relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.invalidTemperature) { try AtmosphericConditions(pressure: p, temperature: .degreesCelsius(200.1), relativeHumidity: 0.5) }
		#expect(throws: AtmosphericConditionsError.invalidRelativeHumidity) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: -0.01) }
		#expect(throws: AtmosphericConditionsError.invalidRelativeHumidity) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 1.01) }
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .micrometers(0.099)) }
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .meters(1.01)) }
	}

	@Test func limitsInOtherUnits() throws {
		// Each limit given in another unit rounds past it in conversion, and is accepted.
		let p = Pressure.hectopascals(1000)
		let t = Temperature.degreesCelsius(10)
		for wavelength in [Distance.meters(1e-7), .micrometers(0.1), .kilometers(0.001), .micrometers(1e6)] {
			_ = try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: wavelength)
		}
		for temperature in [Temperature.kelvins(123.15), .degreesFahrenheit(-238), .kelvins(473.15), .degreesFahrenheit(392)] {
			_ = try AtmosphericConditions(pressure: p, temperature: temperature, relativeHumidity: 0)
		}
		_ = try AtmosphericConditions(pressure: .inchesOfMercury(10_000 / 33.863_89), temperature: t, relativeHumidity: 0.5)
		_ = try AtmosphericConditions(pressure: .pascals(1e6), temperature: t, relativeHumidity: 0.5)
		// 100 µm is optical in any unit.
		let optical = try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .micrometers(100)).refractionConstants
		#expect(try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .meters(1e-4)).refractionConstants == optical)
		// Beyond the rounding, the limits hold.
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .micrometers(0.099_999_99)) }
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions(pressure: p, temperature: t, relativeHumidity: 0.5, wavelength: .micrometers(1.000_000_01e6)) }
		#expect(throws: AtmosphericConditionsError.invalidTemperature) { try AtmosphericConditions(pressure: p, temperature: .kelvins(123.149_999), relativeHumidity: 0) }
		#expect(throws: AtmosphericConditionsError.invalidPressure) { try AtmosphericConditions(pressure: .hectopascals(10_000.000_01), temperature: t, relativeHumidity: 0) }
	}

	@Test func vaporPressure() throws {
		// The vapor-pressure model diverges as the pressure approaches the saturation vapor
		// pressure, here at 6.13 hPa for 10 °C and 50% humidity, which once gave A ≈ -2.2e9.
		let t = Temperature.degreesCelsius(10)
		#expect(throws: AtmosphericConditionsError.invalidVaporPressure) { try AtmosphericConditions(pressure: .hectopascals(6.133_747_705_627_971), temperature: t, relativeHumidity: 0.5) }
		let saturation = AtmosphericConditions.saturationVaporPressure(pressure: 12.3, temperature: 10)
		#expect(saturation > 12 && saturation < 12.5)
		#expect(throws: AtmosphericConditionsError.invalidVaporPressure) { try AtmosphericConditions(pressure: .hectopascals(saturation * 0.999), temperature: t, relativeHumidity: 1e-9) }
		// Just above it, the vapor pressure is at most the pressure and the refraction is small.
		for humidity in [1e-9, 0.5, 1] {
			let pressure = AtmosphericConditions.saturationVaporPressure(pressure: 12.3, temperature: 10) * 1.000_001
			let conditions = try AtmosphericConditions(pressure: .hectopascals(pressure), temperature: t, relativeHumidity: humidity)
			let (a, b) = conditions.refractionConstants
			#expect(a > 0 && a < 1e-5 && abs(b) < 1e-8, "\(humidity)")
		}
		// Dry air and a vacuum have no vapor, at any pressure.
		_ = try AtmosphericConditions(pressure: .hectopascals(1), temperature: .degreesCelsius(30), relativeHumidity: 0)
		#expect(try AtmosphericConditions(pressure: .pascals(0), temperature: t, relativeHumidity: 1).refractionConstants == (0, 0))
		// Humid air too high for its pressure
		#expect(throws: AtmosphericConditionsError.invalidVaporPressure) { try AtmosphericConditions(height: .kilometers(60), temperature: .degreesCelsius(20), relativeHumidity: 0.5) }
		_ = try AtmosphericConditions(height: .kilometers(60), temperature: .degreesCelsius(20), relativeHumidity: 0)
		// In the model, water boils at 1013.25 hPa at about 98.5 °C.
		#expect(throws: AtmosphericConditionsError.invalidVaporPressure) { try AtmosphericConditions(pressure: .standardAtmosphere, temperature: .degreesCelsius(99), relativeHumidity: 1) }
		_ = try AtmosphericConditions(pressure: .standardAtmosphere, temperature: .degreesCelsius(98), relativeHumidity: 1)
	}

	@Test func standardAtmosphere() throws {
		let standard = AtmosphericConditions.standard
		#expect(standard == (try AtmosphericConditions(pressure: .hectopascals(1013.25), temperature: .degreesCelsius(15), relativeHumidity: 0)))
		#expect(standard.wavelength == .micrometers(0.55))
		let (a, b) = standard.refractionConstants
		#expect(abs((a + b) * arcsecondsPerRadian - 57.18) < 0.01)
	}

	@Test func pressureFromHeight() throws {
		// 1013.25 hPa × exp(-h / (29.3 m/K × T))
		let t = Temperature.degreesCelsius(0)
		let maunaKea = try AtmosphericConditions(height: .meters(4205), temperature: t, relativeHumidity: 0.2, wavelength: .micrometers(0.8))
		#expect(abs(maunaKea.pressure.hectopascals - 599.149) < 1e-3)
		#expect(maunaKea.temperature == t)
		#expect(maunaKea.relativeHumidity == 0.2)
		#expect(maunaKea.wavelength == .micrometers(0.8))
		let seaLevel = try AtmosphericConditions(height: .zero, temperature: .degreesCelsius(15), relativeHumidity: 0)
		#expect(seaLevel == .standard)
		// The Dead Sea, below sea level
		#expect(try AtmosphericConditions(height: .meters(-430), temperature: .degreesCelsius(30), relativeHumidity: 0.3).pressure.hectopascals > 1013.25)
		// High above any site the pressure is nearly zero.
		#expect(try AtmosphericConditions(height: .kilometers(100), temperature: t, relativeHumidity: 0).pressure.hectopascals < 0.01)
		#expect(throws: AtmosphericConditionsError.invalidPressure) { try AtmosphericConditions(height: .kilometers(-100), temperature: t, relativeHumidity: 0) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(height: .meters(.nan), temperature: t, relativeHumidity: 0) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions(height: .zero, temperature: .kelvins(.infinity), relativeHumidity: 0) }
		#expect(throws: AtmosphericConditionsError.invalidTemperature) { try AtmosphericConditions(height: .zero, temperature: .degreesCelsius(-151), relativeHumidity: 0) }
		#expect(throws: AtmosphericConditionsError.invalidRelativeHumidity) { try AtmosphericConditions(height: .zero, temperature: t, relativeHumidity: 2) }
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions(height: .zero, temperature: t, relativeHumidity: 0, wavelength: .zero) }
	}

	@Test func standardAtmosphereAtHeight() throws {
		#expect(try AtmosphericConditions.standard(height: .zero) == .standard)
		// ISO 2533 tabulates 89,875 Pa and 8.5 °C at 1 km, and 22,632 Pa and -56.5 °C at 11 km.
		let oneKilometer = try AtmosphericConditions.standard(height: .kilometers(1))
		#expect(abs(oneKilometer.pressure.pascals - 89_875) < 1)
		#expect(abs(oneKilometer.temperature.degreesCelsius - 8.5) < 1e-12)
		let tropopause = try AtmosphericConditions.standard(height: .kilometers(11))
		#expect(abs(tropopause.pressure.pascals - 22_632) < 1)
		#expect(abs(tropopause.temperature.degreesCelsius + 56.5) < 1e-12)
		let below = try AtmosphericConditions.standard(height: .kilometers(-2), relativeHumidity: 0.5, wavelength: .micrometers(2))
		#expect(abs(below.pressure.pascals - 127_774) < 1)
		#expect(below.relativeHumidity == 0.5)
		#expect(below.wavelength == .micrometers(2))
		#expect(throws: AtmosphericConditionsError.invalidHeight) { try AtmosphericConditions.standard(height: .meters(11_000.001)) }
		#expect(throws: AtmosphericConditionsError.invalidHeight) { try AtmosphericConditions.standard(height: .meters(-2_000.001)) }
		#expect(throws: AtmosphericConditionsError.nonFiniteValue) { try AtmosphericConditions.standard(height: .meters(.nan)) }
		#expect(throws: AtmosphericConditionsError.invalidRelativeHumidity) { try AtmosphericConditions.standard(height: .zero, relativeHumidity: -1) }
		#expect(throws: AtmosphericConditionsError.invalidWavelength) { try AtmosphericConditions.standard(height: .zero, wavelength: .zero) }
		// Dry air by default
		#expect(try AtmosphericConditions.standard(height: .kilometers(1)).relativeHumidity == 0)
	}

	@Test func units() {
		#expect(Pressure.hectopascals(1013.25) == .standardAtmosphere)
		#expect(Pressure.standardAtmosphere.hectopascals == 1013.25)
		#expect(abs(Pressure.inchesOfMercury(29.921_25).hectopascals - 1013.25) < 1e-3)
		#expect(abs(Pressure.standardAtmosphere.inchesOfMercury - 29.921_25) < 1e-4)
		#expect(Pressure.pascals(5) < .pascals(6))
		#expect(Pressure.pascals(5).description == "5.0 Pa")
		#expect(Temperature.degreesCelsius(0).kelvins == 273.15)
		#expect(Temperature.kelvins(273.15).degreesCelsius == 0)
		#expect(Temperature.degreesFahrenheit(-40).degreesCelsius == -40)
		#expect(abs(Temperature.degreesFahrenheit(212).kelvins - 373.15) < 1e-12)
		#expect(abs(Temperature.degreesCelsius(37).degreesFahrenheit - 98.6) < 1e-12)
		#expect(Temperature.kelvins(5) < .kelvins(6))
		#expect(Temperature.kelvins(5).description == "5.0 K")
		#expect(abs(Distance.micrometers(0.55).meters - 0.55e-6) < 1e-22)
		#expect(abs(Distance.meters(1).micrometers - 1e6) < 1e-9)
	}

	@Test func codable() throws {
		let pressure = Pressure.hectopascals(1013.25)
		let temperature = Temperature.degreesCelsius(10)
		let pressureData = try JSONEncoder().encode(pressure)
		let temperatureData = try JSONEncoder().encode(temperature)
		#expect(String(decoding: pressureData, as: UTF8.self) == "101325")
		#expect(try JSONDecoder().decode(Pressure.self, from: pressureData) == pressure)
		#expect(try JSONDecoder().decode(Temperature.self, from: temperatureData) == temperature)
	}
}
