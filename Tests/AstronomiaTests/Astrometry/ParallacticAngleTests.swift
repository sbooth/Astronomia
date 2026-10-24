//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct ParallacticAngleTests {
	@Test func matchesERFA() {
		// eraHd2pa of ERFA 2.0.1: the hour angle, declination, latitude, and parallactic angle,
		// in degrees
		let cases: [(Double, Double, Double, Double)] = [
			(30, 20, 40, 45.44473172028668),
			(-45, 10, 51.5, -32.375281815362605),
			(120, -30, -33, 133.17015439739393),
			(0, 50, 40, 180),
			(0, 30, 40, 0),
			(179, 0, 10, 5.65258326893867),
			(-179, 0, 10, -5.65258326893867),
			(60, 89, 45, 119.12261827754385),
			(-60, -10, 90, 0),
			(15, -80, -75, 40.48606784972603),
		]
		for (h, d, phi, expected) in cases {
			let (s, c) = Math.sincos(Angle(degrees: phi).radians)
			let q = Horizon.parallacticAngle(hourAngle: Angle(degrees: h).radians, declination: Angle(degrees: d).radians, sinLatitude: s, cosLatitude: c)
			#expect(abs(Angle(radians: q).degrees - expected) < 1e-9, "\(h) \(d) \(phi)")
		}
		// At the zenith, taken as 0
		#expect(Horizon.parallacticAngle(hourAngle: 0, declination: Angle(degrees: 40).radians, sinLatitude: Math.sin(Angle(degrees: 40).radians), cosLatitude: Math.cos(Angle(degrees: 40).radians)) == 0)
	}

	@Test func zenithFromTheNorthPoint() throws {
		// The parallactic angle is the position angle of the zenith at the target, from the
		// north point through east, found from the target's, the pole's, and the zenith's
		// directions in the site's east, north, and up axes.
		let latitude = Angle(degrees: 19.8207)
		let site = try Observer.site(latitude: latitude, longitude: .degrees(-155.4681), height: .meters(4205))
		let ephemeris = BuiltInEphemeris(precision: .arcsecond)
		let pole = Vector3(0, Math.cos(latitude.radians), Math.sin(latitude.radians))
		for hours in stride(from: 0.0, to: 24, by: 1.5) {
			let sky = try site.observation(at: Instant<TT>(try JulianDate(julianDate: 2_461_050.5 + hours / 24)), ephemeris: ephemeris)
			for body in [BuiltInEphemeris.Body.moon, .sun, .mars] {
				let place = try sky.observedPlace(of: sky.apparentPlace(of: body))
				let (az, alt) = (place.azimuth.radians, place.altitude.radians)
				let m = Vector3(Math.sin(az) * Math.cos(alt), Math.cos(az) * Math.cos(alt), Math.sin(alt))
				let north = pole - m * pole.dot(m)
				let east = pole.cross(m)
				let up = Vector3(0, 0, 1)
				let expected = Math.atan2(up.dot(east) / east.length, up.dot(north) / north.length)
				let difference = (place.parallacticAngle.radians - expected).remainder(dividingBy: twoPi)
				#expect(abs(difference) < 1e-9, "\(body) \(hours) h")
				#expect(place.parallacticAngle.radians > -.pi && place.parallacticAngle.radians <= .pi)
				// West of the meridian it is positive.
				if abs(place.hourAngle.degrees) > 1, abs(place.hourAngle.degrees) < 179 {
					#expect((place.parallacticAngle.radians > 0) == (place.hourAngle.radians > 0), "\(body) \(hours) h")
				}
			}
		}
	}

	@Test func brightLimbFromTheZenith() throws {
		// From a site, the bright limb from the zenith is the bright limb from the north point
		// less the parallactic angle, and the geocenter has none.
		let site = try Observer.site(latitude: .degrees(40), longitude: .degrees(-75))
		let ephemeris = BuiltInEphemeris(precision: .arcsecond)
		let start = Instant<TT>(try JulianDate(julianDate: 2_461_041.5))
		for hours in stride(from: 0.0, to: 48, by: 5) {
			let instant = Instant<TT>(try start.julianDate.adding(days: hours / 24))
			let sky = try site.observation(at: instant, ephemeris: ephemeris)
			let illumination = try sky.illumination(of: .moon)
			let place = try sky.observedPlace(of: sky.apparentPlace(of: .moon))
			let zenith = try #require(illumination.brightLimbZenithAngle)
			let expected = Angle(radians: illumination.brightLimbPositionAngle.radians - place.parallacticAngle.radians).normalized()
			#expect(abs(zenith.radians - expected.radians) < 1e-6 || abs(abs(zenith.radians - expected.radians) - twoPi) < 1e-6)
			#expect(zenith.radians >= 0 && zenith.radians < twoPi)
			let geocentric = try Observer.geocenter.observation(at: instant, ephemeris: ephemeris).illumination(of: .moon)
			#expect(geocentric.brightLimbZenithAngle == nil)
		}
		// A crescent Moon low in the west after sunset, and in the east before sunrise, is lit
		// from below, toward the Sun under the horizon.
		let new = try MoonPhases.next(.newMoon, after: start, precision: .arcsecond)
		for days in [2.5, -2.5] {
			let near = Instant<TT>(try new.julianDate.adding(days: days))
			let sunEvents = try site.riseTransitSetEvents(of: .sun, from: near, to: Instant<TT>(try near.julianDate.adding(days: 1)))
			// An hour after sunset, or before sunrise
			let twilight = days > 0
				? try #require(sunEvents.first { $0.kind == .setting }).instant.julianDate.adding(days: 1.0 / 24)
				: try #require(sunEvents.first { $0.kind == .rising }).instant.julianDate.adding(days: -1.0 / 24)
			let sky = try site.observation(at: Instant<TT>(twilight), ephemeris: ephemeris)
			let illumination = try sky.illumination(of: .moon)
			let place = try sky.observedPlace(of: sky.apparentPlace(of: .moon))
			#expect(place.altitude.degrees > 0)
			let zenith = try #require(illumination.brightLimbZenithAngle).degrees
			#expect(zenith > 90 && zenith < 270, "\(days) d: \(zenith)°")
		}
	}

	@Test func brightLimbFromTheZenithWithPolarMotion() throws {
		// With polar motion, exaggerated to 0.3° and 0.4°, the bright limb from the zenith is the
		// Sun's position angle from the Moon measured from the zenith's direction at the Moon,
		// found here from their unrefracted azimuths and altitudes alone, whatever the poles;
		// the bright limb from the true pole less the parallactic angle, from the ITRS pole,
		// differs from it by the polar motion's turn.
		let motion = PolarMotion(x: .degrees(0.3), y: .degrees(0.4))
		let entries = [2_460_900, 2_461_200].map { EarthOrientationTable.Entry(utcDay: $0, ut1MinusUTC: 0, polarMotion: motion) }
		let ut1 = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
		let site = try Observer.site(latitude: .degrees(40), longitude: .degrees(-75))
		let ephemeris = BuiltInEphemeris(precision: .arcsecond)
		var largest = 0.0
		for (earthOrientation, isExaggerated) in [(EarthOrientation(table: EarthOrientationTable(entries: entries), ut1: ut1), true), (EarthOrientation(ut1: ut1), false)] {
			for hours in stride(from: 0.0, to: 72, by: 7) {
				let instant = Instant<TT>(try JulianDate(julianDate: 2_461_041.5 + hours / 24))
				let sky = try site.observation(at: instant, earthOrientation: earthOrientation, ephemeris: ephemeris)
				let illumination = try sky.illumination(of: .moon)
				let moon = try sky.observedPlace(of: sky.apparentPlace(of: .moon))
				let sun = try sky.observedPlace(of: sky.apparentPlace(of: .sun))
				func vector(_ place: ObservedPlace) -> Vector3 {
					let (az, alt) = (place.azimuth.radians, place.altitude.radians)
					return Vector3(Math.sin(az) * Math.cos(alt), Math.cos(az) * Math.cos(alt), Math.sin(alt))
				}
				let (m, s) = (vector(moon), vector(sun))
				let z = Vector3(0, 0, 1) - m * m.z
				let expected = Angle.atan2(y: s.dot(z.cross(m)), x: s.dot(z)).normalized()
				let zenith = try #require(illumination.brightLimbZenithAngle)
				let difference = Angle(radians: zenith.radians - expected.radians).normalizedSigned()
				#expect(abs(difference.arcseconds) < 1e-3, "\(hours) h")
				let subtracted = Angle(radians: illumination.brightLimbPositionAngle.radians - moon.parallacticAngle.radians - zenith.radians).normalizedSigned()
				if isExaggerated {
					largest = max(largest, abs(subtracted.degrees))
				} else {
					#expect(abs(subtracted.arcseconds) < 0.01, "\(hours) h")
				}
			}
		}
		// The difference is about the polar motion of 0.5°.
		#expect(largest > 0.1 && largest < 1)
	}
}
