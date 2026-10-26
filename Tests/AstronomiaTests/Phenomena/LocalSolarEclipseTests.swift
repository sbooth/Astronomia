//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct LocalSolarEclipseTests {
	/// Returns Earth orientation with a constant ΔT, in seconds.
	static func orientation(deltaT: Double) -> EarthOrientation {
		EarthOrientation(ut1: UT1.Context(deltaT: DeltaTFunction.constant(deltaT)))
	}

	/// Returns the instant of a time of UT on 2001 June 21, from its time of day, with a ΔT.
	static func instant(_ time: String, deltaT: Double) throws -> Instant<TT> {
		let parts = time.split(separator: ":").map { Double($0)! }
		let seconds = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
		return Instant(try JulianDate(year: 2001, month: 6, day: 21).adding(seconds: seconds + deltaT))
	}

	/// Returns the seconds from one instant to another.
	static func seconds(from start: Instant<TT>, to end: Instant<TT>) throws -> Double {
		try start.julianDate.interval(to: end.julianDate).inSeconds
	}

	/// Returns the difference of two angles, in degrees, reduced to [-180, 180).
	static func difference(_ a: Angle, _ b: Double) -> Double {
		(a.degrees - b + 540).truncatingRemainder(dividingBy: 360) - 180
	}

	/// The total eclipse of 2001 June 21.
	static func eclipse() throws -> Sun.Eclipse {
		try Sun.nextEclipse(after: Instant<TT>(try JulianDate(year: 2001, month: 6, day: 20)), precision: .tenthArcsecond)
	}

	@Test func nasaCentralLine() throws {
		// Points of the central line of the total eclipse of 2001 June 21 from NASA's path, with
		// ΔT = 64.2 s, at sea level: the UT at which the axis passes, and so of maximum, the
		// latitude and longitude, the central duration, in seconds, and the Sun's altitude.
		let eclipse = try Self.eclipse()
		let line: [(time: String, latitude: Double, longitude: Double, duration: Double, altitude: Double)] = [
			("10:40", -(30 + 40.0 / 60), -(37 + 58.1 / 60), 154.3, 12),
			("10:50", -(24 + 25.9 / 60), -(26 + 36.7 / 60), 191.5, 26),
			("11:20", -(16 + 5.5 / 60), -(11 + 19.8 / 60), 257.4, 45),
			("11:50", -(12 + 10.8 / 60), -(1 + 23.2 / 60), 291.7, 54),
			("12:04", -(11 + 14.6 / 60), 2 + 50.4 / 60, 296.6, 55),
			("12:30", -(10 + 51.7 / 60), 10 + 55.2 / 60, 285.5, 51),
			("13:00", -(13 + 4.8 / 60), 22 + 24.6 / 60, 240.6, 39),
			("13:20", -(17 + 39.6 / 60), 34 + 46.3 / 60, 189.2, 23),
			("13:28", -(22 + 5.7 / 60), 44 + 52.9 / 60, 155.8, 11),
		]
		for point in line {
			let site = try Observer.site(latitude: .degrees(point.latitude), longitude: .degrees(point.longitude))
			let local = try #require(try site.localCircumstances(of: eclipse, earthOrientation: Self.orientation(deltaT: 64.2), precision: .tenthArcsecond), "\(point.time)")
			#expect(local.kind == .total && local.magnitude > 1 && local.obscuration == 1, "\(point.time)")
			let central = try #require(local.centralPhase, "\(point.time)")
			#expect(abs(try Self.seconds(from: central.lowerBound, to: central.upperBound) - point.duration) < 0.2, "\(point.time)")
			let maximum = try #require(local.circumstance(at: .maximum))
			#expect(abs(try Self.seconds(from: Self.instant(point.time, deltaT: 64.2), to: maximum.instant)) < 1, "\(point.time)")
			#expect(abs(maximum.place.altitude.degrees - point.altitude) < 0.6 && maximum.isSunUp, "\(point.time)")
			#expect(local.contacts.map(\.contact) == Sun.LocalEclipse.Contact.allCases, "\(point.time)")
			#expect(zip(local.contacts, local.contacts.dropFirst()).allSatisfy { $0.instant < $1.instant }, "\(point.time)")
		}
	}

	@Test func nasaCentralLineContacts() throws {
		// The contacts on the central line from NASA's bulletin for the eclipse, with
		// ΔT = 65.0 s, at the path's points: the UT, and the position angles P and V, in
		// degrees, of C1, C2, C3, and C4.
		let eclipse = try Self.eclipse()
		let line: [(latitude: Double, longitude: Double, contacts: [(time: String?, p: Double, v: Double)])] = [
			(-(24 + 25.9 / 60), -(26 + 36.7 / 60), [("09:37:35", 253, 17), (nil, 73, 207), (nil, 253, 28), ("12:13:21", 74, 226)]),
			(-(20 + 48.2 / 60), -(20 + 11.8 / 60), [("09:42:14", 252, 17), (nil, 73, 212), (nil, 253, 32), ("12:29:46", 75, 237)]),
			(-(13 + 4.8 / 60), 22 + 24.6 / 60, [("11:24:49", 268, 109), (nil, 91, 319), (nil, 271, 140), ("14:21:35", 93, 336)]),
			(-(17 + 39.6 / 60), 34 + 46.3 / 60, [("11:57:12", 272, 134), (nil, 94, 331), (nil, 274, 151), ("14:30:45", 94, 341)]),
		]
		for point in line {
			let site = try Observer.site(latitude: .degrees(point.latitude), longitude: .degrees(point.longitude))
			let local = try #require(try site.localCircumstances(of: eclipse, earthOrientation: Self.orientation(deltaT: 65.0), precision: .tenthArcsecond))
			for (contact, expected) in zip([Sun.LocalEclipse.Contact.partialBegins, .centralBegins, .centralEnds, .partialEnds], point.contacts) {
				let circumstance = try #require(local.circumstance(at: contact))
				#expect(abs(Self.difference(circumstance.positionAngle, expected.p)) < 1 && abs(Self.difference(circumstance.zenithPositionAngle, expected.v)) < 1, "\(point.latitude) \(contact)")
				if let time = expected.time {
					#expect(abs(try Self.seconds(from: Self.instant(time, deltaT: 65.0), to: circumstance.instant)) < 3, "\(point.latitude) \(contact)")
				}
			}
		}
	}

	@Test func nasaPartialSites() throws {
		// Four sites of the Indian Ocean from NASA's bulletin, with ΔT = 65.0 s: the latitude,
		// longitude, and height, in meters, C1 and C4, each with its UT, its position angles P
		// and V, and the Sun's altitude, in degrees, or `nil` for C4 after sunset, and maximum,
		// with its UT, the Sun's altitude, and the magnitude and obscuration.
		let eclipse = try Self.eclipse()
		let sites: [(name: String, latitude: Double, longitude: Double, height: Double, first: (String, Double, Double, Double), last: (String, Double, Double, Double)?, maximum: (String, Double), magnitude: Double, obscuration: Double)] = [
			("Moroni", -(11 + 41 / 60.0), 43 + 16 / 60.0, 0, ("12:18:55.4", 259, 137, 32), ("14:33:54.9", 110, 6, 3), ("13:31:14.7", 17), 0.749, 0.692),
			("Port Louis", -(20 + 10 / 60.0), 57 + 30 / 60.0, 55, ("12:31:44.9", 263, 144, 13), nil, ("13:35:16.9", 1), 0.808, 0.765),
			("St.-Denis", -(20 + 52 / 60.0), 55 + 28 / 60.0, 936, ("12:29:00.5", 265, 144, 15), nil, ("13:34:21.6", 2), 0.854, 0.823),
			("Victoria", -(4 + 38 / 60.0), 55 + 27 / 60.0, 5, ("12:48:01.2", 236, 132, 19), nil, ("13:38:36.9", 8), 0.378, 0.265),
		]
		for expected in sites {
			let site = try Observer.site(latitude: .degrees(expected.latitude), longitude: .degrees(expected.longitude), height: .kilometers(expected.height / 1000))
			let local = try #require(try site.localCircumstances(of: eclipse, earthOrientation: Self.orientation(deltaT: 65.0), precision: .tenthArcsecond), "\(expected.name)")
			#expect(local.kind == .partial && local.centralPhase == nil && local.circumstance(at: .centralBegins) == nil, "\(expected.name)")
			#expect(abs(local.magnitude - expected.magnitude) < 0.0006 && abs(local.obscuration - expected.obscuration) < 0.0006, "\(expected.name)")
			let first = try #require(local.circumstance(at: .partialBegins))
			#expect(abs(try Self.seconds(from: Self.instant(expected.first.0, deltaT: 65.0), to: first.instant)) < 0.5, "\(expected.name)")
			#expect(abs(Self.difference(first.positionAngle, expected.first.1)) < 1 && abs(Self.difference(first.zenithPositionAngle, expected.first.2)) < 1, "\(expected.name)")
			#expect(abs(first.place.altitude.degrees - expected.first.3) < 0.6 && first.isSunUp, "\(expected.name)")
			let maximum = try #require(local.circumstance(at: .maximum))
			#expect(abs(try Self.seconds(from: Self.instant(expected.maximum.0, deltaT: 65.0), to: maximum.instant)) < 2, "\(expected.name)")
			#expect(abs(maximum.place.altitude.degrees - expected.maximum.1) < 1.1, "\(expected.name)")
			let last = try #require(local.circumstance(at: .partialEnds))
			if let expectedLast = expected.last {
				#expect(abs(try Self.seconds(from: Self.instant(expectedLast.0, deltaT: 65.0), to: last.instant)) < 0.5, "\(expected.name)")
				#expect(abs(Self.difference(last.positionAngle, expectedLast.1)) < 1 && abs(Self.difference(last.zenithPositionAngle, expectedLast.2)) < 1, "\(expected.name)")
				#expect(abs(last.place.altitude.degrees - expectedLast.3) < 0.6, "\(expected.name)")
			} else {
				// The Sun has set, and the visible part of the eclipse ends at sunset.
				#expect(!last.isSunUp, "\(expected.name)")
				let set = try #require(local.sunrisesAndSunsets.last)
				#expect(set.kind == .set && local.visibleIntervals.count == 1 && local.visibleIntervals[0] == first.instant ... set.instant, "\(expected.name)")
				#expect(local.visibleIntervals(of: local.partialPhase) == local.visibleIntervals)
			}
		}
	}

	@Test func matchesGreatestEclipse() throws {
		// At the place of greatest eclipse of eclipses of each kind, the eclipse is seen as the
		// search for eclipses finds it from the shadow's geometry: of the same kind, the central
		// phase as long, and maximum at greatest eclipse; and from the other side of the Earth,
		// not at all.
		let start = Instant<TT>(try JulianDate(year: 2023, month: 1, day: 1))
		let eclipses = try Sun.eclipses(from: start, to: Instant<TT>(try JulianDate(year: 2026, month: 1, day: 1)), precision: .tenthArcsecond)
		#expect(Set(eclipses.map(\.kind)) == [.hybrid, .annular, .total, .partial])
		for eclipse in eclipses {
			let date = "\(eclipse.greatestEclipse)"
			let greatest = eclipse.greatestEclipseSite
			let site = try Observer.site(latitude: greatest.latitude, longitude: greatest.longitude)
			let local = try #require(try site.localCircumstances(of: eclipse, precision: .tenthArcsecond), "\(date)")
			let maximum = try #require(local.circumstance(at: .maximum))
			switch eclipse.kind {
			case .partial:
				// At the Earth's limb nearest the axis, with the Sun on the horizon
				#expect(local.kind == .partial && abs(local.magnitude - eclipse.magnitude) < 0.001 && abs(maximum.place.altitude.degrees) < 0.2, "\(date)")
			case .total, .annular, .hybrid:
				#expect(local.kind == (eclipse.kind == .annular ? .annular : .total), "\(date)")
				// The ratio of the Moon's apparent diameter to the Sun's, as the eclipse's
				#expect(abs(local.magnitude - eclipse.magnitude) < 0.0002 && (local.magnitude > 1) == (local.kind == .total), "\(date)")
				let central = try #require(local.centralPhase)
				let expected = try #require(greatest.centralPhase)
				#expect(abs(try Self.seconds(from: central.lowerBound, to: central.upperBound) - Self.seconds(from: expected.lowerBound, to: expected.upperBound)) < 0.05, "\(date)")
				#expect(abs(try Self.seconds(from: eclipse.greatestEclipse, to: maximum.instant)) < 1, "\(date)")
				#expect(abs(maximum.place.altitude.degrees - greatest.sunAltitude.degrees) < 0.01, "\(date)")
			}
			let antipode = try Observer.site(latitude: Angle(degrees: -greatest.latitude.degrees), longitude: Angle(degrees: greatest.longitude.degrees + 180))
			#expect(try antipode.localCircumstances(of: eclipse, precision: .arcsecond) == nil, "\(date)")
		}
	}

	@Test func sunrise() throws {
		// At Buenos Aires the eclipse of 2001 June 21 was in progress at sunrise: it is visible
		// from sunrise to its end. Its maximum was before sunrise, deeper than the 0.537 NASA
		// gives at sunrise.
		let site = try Observer.site(latitude: .degrees(-(34 + 36 / 60.0)), longitude: .degrees(-(58 + 23 / 60.0)))
		let local = try #require(try site.localCircumstances(of: Self.eclipse(), precision: .tenthArcsecond))
		let first = try #require(local.circumstance(at: .partialBegins))
		let last = try #require(local.circumstance(at: .partialEnds))
		#expect(local.kind == .partial && !first.isSunUp && last.isSunUp)
		let rise = try #require(local.sunrisesAndSunsets.first)
		#expect(rise.kind == .rise && local.sunrisesAndSunsets.count == 1)
		#expect(local.visibleIntervals == [rise.instant ... last.instant] && local.isVisible)
		#expect(local.circumstance(at: .maximum)?.isSunUp == false && local.magnitude > 0.8)
		// While the Sun is up the eclipse is deepest at sunrise, as NASA gives it for the city,
		// whose coordinates it doesn't give, when the magnitude falls by 0.004 a minute.
		try #expect(abs(#require(local.visibleMagnitude) - 0.537) < 0.01 && abs(#require(local.visibleObscuration) - 0.437) < 0.01)
		#expect(abs(try site.magnitude(of: local.eclipse, at: rise.instant, precision: .tenthArcsecond) - local.visibleMagnitude!) < 1e-6)
	}

	@Test func centralMagnitude() throws {
		// Within the central phase the magnitude is the ratio of the diameters, the same
		// wherever the Moon is within the Sun, or the Sun within the Moon.
		let sample = LocalSolarEclipseSample(time: 0, separation: 0, sun: 0.0045, penumbralMoon: 0.0045 * 1.1, umbralMoon: 0.0045 * 1.1)
		#expect(abs(sample.magnitude - 1.1) < 1e-12 && sample.obscuration == 1)
		let annular = LocalSolarEclipseSample(time: 0, separation: 0.0001, sun: 0.0045, penumbralMoon: 0.0045 * 0.9, umbralMoon: 0.0045 * 0.9)
		#expect(abs(annular.magnitude - 0.9) < 1e-12 && abs(annular.obscuration - 0.81) < 1e-12)
		// In the partial phase, the fraction of the Sun's diameter covered, which at the
		// internal contact of an annular eclipse is the ratio
		let contact = LocalSolarEclipseSample(time: 0, separation: 0.0045 * 0.1, sun: 0.0045, penumbralMoon: 0.0045 * 0.9, umbralMoon: 0.0045 * 0.9)
		let partial = LocalSolarEclipseSample(time: 0, separation: 0.0045, sun: 0.0045, penumbralMoon: 0.0045 * 0.9, umbralMoon: 0.0045 * 0.9)
		#expect(abs(contact.magnitude - 0.9) < 1e-9 && abs(partial.magnitude - 0.45) < 1e-12)
	}

	@Test func elevatedSite() throws {
		// Above the point where the penumbra first touches the Earth's surface, at P1, a site
		// 10 km high sees the eclipse about 11 s sooner: its first contact is before P1, and is a
		// contact, with the disks apart a minute before and overlapping a minute after.
		let eclipse = try Self.eclipse()
		let search = SolarEclipseSearch(origin: eclipse.partialPhase.lowerBound.julianDate, moon: BuiltInEphemeris.Body.moon, earthOrientation: .model, ephemeris: BuiltInEphemeris(precision: .tenthArcsecond), radii: eclipse.radii)
		let first = try search.site(search.sample(0))
		let site = try Observer.site(latitude: first.latitude, longitude: first.longitude, height: .kilometers(10))
		let local = try #require(try site.localCircumstances(of: eclipse, precision: .tenthArcsecond))
		let begins = local.partialPhase.lowerBound
		#expect(try Self.seconds(from: begins, to: eclipse.partialPhase.lowerBound) > 5)
		#expect(try site.magnitude(of: eclipse, at: Instant<TT>(begins.julianDate.adding(seconds: -60)), precision: .tenthArcsecond) == 0)
		#expect(try site.magnitude(of: eclipse, at: Instant<TT>(begins.julianDate.adding(seconds: 60)), precision: .tenthArcsecond) > 0)
		#expect(try site.magnitude(of: eclipse, at: begins, precision: .tenthArcsecond) < 1e-6)
		#expect(zip(local.contacts, local.contacts.dropFirst()).allSatisfy { $0.instant < $1.instant })
	}

	@Test func sunset() throws {
		// East of Mauritius the eclipse was visible until sunset, deepest then, and farther east
		// it was wholly after sunset, so not visible.
		let eclipse = try Self.eclipse()
		let west = try #require(try Observer.site(latitude: .degrees(-20), longitude: .degrees(70)).localCircumstances(of: eclipse, precision: .tenthArcsecond))
		let set = try #require(west.sunrisesAndSunsets.first)
		#expect(set.kind == .set && west.isVisible && west.visibleIntervals == [west.partialPhase.lowerBound ... set.instant])
		#expect(try #require(west.visibleMagnitude) < west.magnitude && west.visibleObscuration! < west.obscuration)
		let east = try #require(try Observer.site(latitude: .degrees(-20), longitude: .degrees(75)).localCircumstances(of: eclipse, precision: .tenthArcsecond))
		#expect(!east.isVisible && east.visibleIntervals.isEmpty && east.visibleMagnitude == nil && east.visibleObscuration == nil)
		#expect(east.contacts.allSatisfy { !$0.isSunUp } && east.magnitude > 0.5)
	}

	@Test func magnitudeAtAnInstant() throws {
		// The magnitude from a site at an instant: at maximum that of the local circumstances,
		// at the contacts of the partial phase 0, and outside it 0; in UTC as in TT.
		let eclipse = try Self.eclipse()
		let site = try Observer.site(latitude: .degrees(-(11 + 41 / 60.0)), longitude: .degrees(43 + 16 / 60.0))
		let local = try #require(try site.localCircumstances(of: eclipse, precision: .tenthArcsecond))
		#expect(local.visibleMagnitude == local.magnitude && local.visibleObscuration == local.obscuration)
		let maximum = try #require(local.circumstance(at: .maximum))
		#expect(abs(try site.magnitude(of: eclipse, at: maximum.instant, precision: .tenthArcsecond) - local.magnitude) < 1e-9)
		for contact in [local.partialPhase.lowerBound, local.partialPhase.upperBound] {
			#expect(try site.magnitude(of: eclipse, at: contact, precision: .tenthArcsecond) < 1e-6)
		}
		let before = Instant<TT>(try local.partialPhase.lowerBound.julianDate.adding(seconds: -600))
		#expect(try site.magnitude(of: eclipse, at: before, precision: .tenthArcsecond) == 0)
		let during = Instant<TT>(try maximum.instant.julianDate.adding(seconds: -1800))
		let magnitude = try site.magnitude(of: eclipse, at: during, precision: .tenthArcsecond)
		#expect(magnitude > 0 && magnitude < local.magnitude)
		#expect(abs(try site.magnitude(of: eclipse, at: during.converted(to: UTC.self), precision: .tenthArcsecond) - magnitude) < 1e-9)
		#expect(throws: Sun.EclipseError.noHorizon) { try Observer.geocenter.magnitude(of: eclipse, at: during) }
	}

	@Test func visibleEclipses() throws {
		// From Carbondale, Illinois, in totality in 2017 and in 2024
		let site = try Observer.site(latitude: .degrees(37.7273), longitude: .degrees(-89.2168), height: .kilometers(0.125))
		let visible = try site.visibleSolarEclipses(from: Instant<TT>(try JulianDate(year: 2017, month: 1, day: 1)), to: Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1)), precision: .arcsecond)
		#expect(visible.allSatisfy { $0.isVisible })
		let totals = visible.filter { $0.kind == .total }
		#expect(totals.count == 2)
		#expect(abs(totals[0].eclipse.greatestEclipse.julianDate.daysSinceJ2000 - (2_457_987.27 - 2_451_545)) < 0.1)
		#expect(abs(totals[1].eclipse.greatestEclipse.julianDate.daysSinceJ2000 - (2_460_409.26 - 2_451_545)) < 0.1)
		#expect(visible.contains { $0.kind == .partial && abs($0.eclipse.greatestEclipse.julianDate.daysSinceJ2000 - (2_460_232.25 - 2_451_545)) < 0.1 })
		for local in totals {
			#expect(try local.centralPhase.map { try Self.seconds(from: $0.lowerBound, to: $0.upperBound) }! > 60)
		}
	}

	@Test func errors() throws {
		let eclipse = try Self.eclipse()
		#expect(throws: Sun.EclipseError.noHorizon) { try Observer.geocenter.localCircumstances(of: eclipse) }
		#expect(throws: Sun.EclipseError.noHorizon) {
			try Observer.geocenter.visibleSolarEclipses(from: eclipse.partialPhase.lowerBound, to: eclipse.partialPhase.upperBound)
		}
	}
}
