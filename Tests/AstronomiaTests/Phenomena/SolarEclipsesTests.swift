//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct SolarEclipsesTests {
	static func julianDate(_ instant: Instant<TT>) -> Double {
		instant.julianDate.daysSinceJ2000 + 2_451_545
	}

	/// Returns the seconds from one instant to another.
	static func seconds(from start: Instant<TT>, to end: Instant<TT>) throws -> Double {
		try start.julianDate.interval(to: end.julianDate).inSeconds
	}

	/// Returns an instant of TT on a day, from its time of day.
	static func instant(_ year: Int, _ month: Int, _ day: Int, _ time: String) throws -> Instant<TT> {
		let parts = time.split(separator: ":").map { Double($0)! }
		let midnight = try JulianDate(year: year, month: month, day: day)
		return Instant(try midnight.adding(seconds: parts[0] * 3600 + parts[1] * 60 + parts[2]))
	}

	/// Returns the instant of greatest eclipse of a NASA eclipse.
	static func greatest(_ index: Int) throws -> Instant<TT> {
		let eclipse = nasaSolarEclipses[index]
		let midnight = try JulianDate(year: eclipse.year, month: eclipse.month, day: eclipse.day)
		return Instant(try midnight.adding(seconds: Double(eclipse.hour * 3600 + eclipse.minute * 60 + eclipse.second)))
	}

	/// Returns whether two eclipses are the same, found from searches with other origins, so
	/// to within the precision of the search.
	static func same(_ a: Sun.Eclipse, _ b: Sun.Eclipse) throws -> Bool {
		try a.kind == b.kind && abs(seconds(from: a.greatestEclipse, to: b.greatestEclipse)) < 0.05 && abs(a.magnitude - b.magnitude) < 1e-6
	}

	/// The value of a polynomial at a time.
	static func value(_ coefficients: [Double], _ t: Double) -> Double {
		coefficients.reversed().reduce(0) { $0 * t + $1 }
	}

	@Test func besselianElements() throws {
		// The geometry of the shadow over 6 hours matches NASA's Besselian elements, with the
		// VSOP87 and ELP2000-85 theories, to about 0.6 km on the fundamental plane.
		for elements in nasaBesselianElements {
			let origin = try JulianDate(year: elements.year, month: elements.month, day: elements.day, fractionSinceMidnight: Double(elements.hour) / 24)
			let search = SolarEclipseSearch(origin: origin, moon: BuiltInEphemeris.Body.moon, earthOrientation: .model, ephemeris: BuiltInEphemeris(precision: .arcsecond), radii: .nasa)
			for hours in stride(from: -3.0, through: 3.0, by: 1) {
				let sample = try search.sample(hours / 24)
				let date = "\(elements.year)-\(elements.month)-\(elements.day) \(hours)"
				#expect(abs(sample.x - Self.value(elements.x, hours)) < 2e-4, "\(date)")
				#expect(abs(sample.y - Self.value(elements.y, hours)) < 2e-4, "\(date)")
				#expect(abs(Angle(radians: sample.declination).degrees - Self.value(elements.d, hours)) < 5e-5, "\(date)")
				#expect(abs(sample.l1 - Self.value(elements.l1, hours)) < 3e-5, "\(date)")
				#expect(abs(sample.l2 - Self.value(elements.l2, hours)) < 1e-5, "\(date)")
				#expect(abs(sample.tanF1 - elements.tanF1) < 5e-7 && abs(sample.tanF2 - elements.tanF2) < 5e-7, "\(date)")
			}
		}
	}

	@Test func matchesNASA() throws {
		// Every third eclipse from 2001 to 2100, and every hybrid and every eclipse that isn't
		// central, of NASA's Five Millennium Catalog, with the VSOP87 and ELP-2000/82 theories
		for (index, expected) in nasaSolarEclipses.enumerated() where index % 3 == 0 || expected.kind == .hybrid || expected.qualifier == "+" || expected.qualifier == "-" {
			let greatest = try Self.greatest(index)
			let eclipse = try Sun.nextEclipse(after: Instant<TT>(try greatest.julianDate.adding(days: -2)), precision: .arcsecond)
			let date = "\(expected.year)-\(expected.month)-\(expected.day)"
			let isCentral = !(expected.kind == .partial || expected.qualifier == "+" || expected.qualifier == "-")
			#expect(eclipse.kind == expected.kind && eclipse.isCentral == isCentral, "\(date)")
			#expect(abs(try Self.seconds(from: greatest, to: eclipse.greatestEclipse)) < 1.2, "\(date)")
			#expect(abs(eclipse.gamma - expected.gamma) < 0.0002, "\(date)")
			#expect(abs(eclipse.magnitude - expected.magnitude) < 0.0002, "\(date)")
		}
	}

	@Test func matchesEclipseWise() throws {
		// The contacts of four eclipses from Espenak's EclipseWise, with DE405 and its radii of
		// the Moon: P1, U1, C1, C2, U4, and P4, greatest eclipse, gamma, and magnitude.
		let radii = try Sun.Eclipse.Radii(penumbralMoon: 0.272_507_6, umbralMoon: 0.272_281_0, sun: Angle(arcseconds: 959.63))
		let eclipses: [(year: Int, month: Int, day: Int, kind: Sun.Eclipse.Kind, contacts: [String?], greatest: String, gamma: Double, magnitude: Double)] = [
			(2023, 4, 20, .hybrid, ["01:35:34.3", "02:38:15.0", "02:38:18.4", "05:57:47.4", "05:57:53.5", "07:00:31.9"], "04:17:56.0", -0.395_15, 1.013_20),
			(2023, 10, 14, .annular, ["15:04:58.2", "16:11:19.0", "16:13:35.5", "19:47:59.2", "19:50:13.1", "20:56:26.7"], "18:00:40.6", 0.375_34, 0.952_04),
			(2024, 4, 8, .total, ["15:43:23.3", "16:40:00.7", "16:41:09.4", "19:55:38.1", "19:56:45.7", "20:53:30.4"], "18:18:29.4", 0.343_14, 1.056_56),
			(2025, 3, 29, .partial, ["08:51:52.5", nil, nil, nil, nil, "12:44:54.0"], "10:48:36.1", 1.040_53, 0.937_60),
		]
		for expected in eclipses {
			let date = "\(expected.year)-\(expected.month)-\(expected.day)"
			let from = Instant<TT>(try JulianDate(year: expected.year, month: expected.month, day: expected.day - 1))
			let eclipse = try Sun.nextEclipse(after: from, precision: .tenthArcsecond, radii: radii)
			#expect(eclipse.kind == expected.kind && eclipse.radii == radii, "\(date)")
			let contacts = [eclipse.partialPhase.lowerBound, eclipse.umbralPhase?.lowerBound, eclipse.centralPhase?.lowerBound, eclipse.centralPhase?.upperBound, eclipse.umbralPhase?.upperBound, eclipse.partialPhase.upperBound]
			for (contact, time) in zip(contacts, expected.contacts) {
				#expect((contact == nil) == (time == nil), "\(date)")
				if let contact, let time {
					#expect(abs(try Self.seconds(from: Self.instant(expected.year, expected.month, expected.day, time), to: contact)) < 0.5, "\(date) \(time)")
				}
			}
			#expect(abs(try Self.seconds(from: Self.instant(expected.year, expected.month, expected.day, expected.greatest), to: eclipse.greatestEclipse)) < 0.5, "\(date)")
			#expect(abs(eclipse.gamma - expected.gamma) < 2e-5 && abs(eclipse.magnitude - expected.magnitude) < 2e-5, "\(date)")
		}
	}

	@Test func events() throws {
		// The eclipses from 2024 to 2027, in order, with their contacts in order, each where its
		// circle meets the Earth's outline.
		let start = Instant<TT>(try JulianDate(year: 2024, month: 1, day: 1))
		let end = Instant<TT>(try JulianDate(year: 2028, month: 1, day: 1))
		let eclipses = try Sun.eclipses(from: start, to: end, precision: .arcsecond)
		let expected = nasaSolarEclipses.filter { $0.year >= 2024 && $0.year < 2028 }
		#expect(eclipses.count == expected.count && expected.count == 8)
		#expect(eclipses.map(\.kind) == expected.map(\.kind))
		for eclipse in eclipses {
			#expect(eclipse.radii == .nasa)
			#expect((eclipse.umbralPhase == nil) == (eclipse.kind == .partial))
			#expect((eclipse.centralPhase == nil) == !eclipse.isCentral)
			let contacts = [eclipse.partialPhase.lowerBound, eclipse.umbralPhase?.lowerBound, eclipse.centralPhase?.lowerBound, eclipse.greatestEclipse, eclipse.centralPhase?.upperBound, eclipse.umbralPhase?.upperBound, eclipse.partialPhase.upperBound].compactMap { $0 }
			#expect(zip(contacts, contacts.dropFirst()).allSatisfy { $0 < $1 })
			// At each contact the axis is the radius of its circle from the Earth's outline, to
			// within its motion over the precision of the contact, 0.1 s.
			let sample = { (instant: Instant<TT>) in
				try SolarEclipseSearch(origin: instant.julianDate, moon: BuiltInEphemeris.Body.moon, earthOrientation: .model, ephemeris: BuiltInEphemeris(precision: .arcsecond), radii: .nasa).sample(0)
			}
			let p1 = try sample(eclipse.partialPhase.lowerBound)
			let p4 = try sample(eclipse.partialPhase.upperBound)
			#expect(abs(p1.edge - p1.l1) < 2e-5 && abs(p4.edge - p4.l1) < 2e-5)
			if let umbralPhase = eclipse.umbralPhase {
				for contact in [try sample(umbralPhase.lowerBound), try sample(umbralPhase.upperBound)] {
					#expect(abs(contact.edge - abs(contact.l2)) < 2e-5)
				}
			}
			if let centralPhase = eclipse.centralPhase {
				for contact in [try sample(centralPhase.lowerBound), try sample(centralPhase.upperBound)] {
					#expect(abs(contact.edge) < 2e-5)
				}
			}
		}
	}

	@Test func intervalEnds() throws {
		// An eclipse greatest just within either end of an interval is found, though its new
		// Moon is outside it, and one just outside isn't.
		let eclipse = try Sun.nextEclipse(after: Instant<TT>(try JulianDate(year: 2026, month: 2, day: 1)), precision: .arcsecond)
		let greatest = eclipse.greatestEclipse
		let new = try Moon.nextPhase(.newMoon, after: Instant<TT>(try greatest.julianDate.adding(days: -1)), precision: .arcsecond).instant
		#expect(abs(try Self.seconds(from: new, to: greatest)) > 120)
		for (before, after) in [(2.0, 60.0), (60, 2), (2, 3)] {
			let found = try Sun.eclipses(from: Instant<TT>(try greatest.julianDate.adding(seconds: -before)), to: Instant<TT>(try greatest.julianDate.adding(seconds: after)), precision: .arcsecond)
			#expect(found.count == 1, "\(before) \(after)")
			#expect(try found.first.map { try Self.same($0, eclipse) } == true)
		}
		#expect(try Sun.eclipses(from: Instant<TT>(try greatest.julianDate.adding(seconds: -3600)), to: Instant<TT>(try greatest.julianDate.adding(seconds: -2)), precision: .arcsecond).isEmpty)
		#expect(try Sun.eclipses(from: Instant<TT>(try greatest.julianDate.adding(seconds: 2)), to: Instant<TT>(try greatest.julianDate.adding(seconds: 3600)), precision: .arcsecond).isEmpty)
	}

	@Test func next() throws {
		// From an eclipse's greatest eclipse, the next; from a second before it, that one; and in
		// UTC as in TT.
		let start = Instant<TT>(try JulianDate(year: 2026, month: 1, day: 1))
		var eclipse = try Sun.nextEclipse(after: start, precision: .arcsecond)
		let expected = nasaSolarEclipses.filter { $0.year >= 2026 && $0.year < 2028 }
		for row in expected {
			#expect(eclipse.kind == row.kind)
			let before = try Sun.nextEclipse(after: Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(seconds: -1)), precision: .arcsecond)
			#expect(try Self.same(before, eclipse))
			let next = try Sun.nextEclipse(after: eclipse.greatestEclipse, precision: .arcsecond)
			#expect(Self.julianDate(next.greatestEclipse) - Self.julianDate(eclipse.greatestEclipse) > 25)
			eclipse = next
		}
		let utc = try start.converted(to: UTC.self)
		#expect(try Self.same(try Sun.nextEclipse(after: utc, precision: .arcsecond), try Sun.nextEclipse(after: start, precision: .arcsecond)))
	}

	@Test func radii() throws {
		#expect(Sun.Eclipse.Radii.nasa.penumbralMoon == 0.272_488_0 && Sun.Eclipse.Radii.nasa.umbralMoon == 0.272_281_0)
		#expect(Sun.Eclipse.Radii.nasa.sun == Angle(arcseconds: 959.63))
		#expect(try Sun.Eclipse.Radii(penumbralMoon: 0.272_488_0, umbralMoon: 0.272_281_0, sun: Angle(arcseconds: 959.63)) == .nasa)
		for (penumbral, umbral, sun, error) in [(Double.nan, 0.27, 960.0, Sun.EclipseRadiiError.nonFiniteValue), (0.27, .infinity, 960, .nonFiniteValue), (0.27, 0.27, .nan, .nonFiniteValue), (0, 0.27, 960, .nonPositiveValue), (0.27, -0.27, 960, .nonPositiveValue), (0.27, 0.27, 0, .nonPositiveValue)] {
			#expect(throws: error) {
				try Sun.Eclipse.Radii(penumbralMoon: penumbral, umbralMoon: umbral, sun: Angle(arcseconds: sun))
			}
		}
		// A larger Moon covers more of the Sun, and a larger Sun less.
		let from = Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1))
		let nasa = try Sun.nextEclipse(after: from, precision: .arcsecond)
		let largerMoon = try Sun.nextEclipse(after: from, precision: .arcsecond, radii: Sun.Eclipse.Radii(penumbralMoon: 0.28, umbralMoon: 0.28, sun: Angle(arcseconds: 959.63)))
		let largerSun = try Sun.nextEclipse(after: from, precision: .arcsecond, radii: Sun.Eclipse.Radii(penumbralMoon: 0.272_488_0, umbralMoon: 0.272_281_0, sun: Angle(arcseconds: 1000)))
		#expect(nasa.kind == .partial && largerMoon.magnitude > nasa.magnitude && largerSun.magnitude < nasa.magnitude)
		#expect(largerMoon.partialPhase.lowerBound < nasa.partialPhase.lowerBound)
	}

	@Test func errors() throws {
		let start = Instant<TT>(try JulianDate(year: 2025, month: 1, day: 1))
		#expect(throws: Sun.EclipseError.invalidInterval) {
			try Sun.eclipses(from: start, to: Instant<TT>(try JulianDate(year: 2024, month: 1, day: 1)), precision: .arcsecond)
		}
		#expect(try Sun.eclipses(from: start, to: start, precision: .arcsecond).isEmpty)
		#expect(throws: Sun.EclipseError.ephemeris(.outsideCoverage)) {
			try Sun.nextEclipse(after: Instant<TT>(try JulianDate(year: 3000, month: 6, day: 1)), precision: .tenArcseconds)
		}
		#expect(throws: Sun.EclipseError.timescaleConversion(.unsupported)) {
			try Sun.eclipses(from: Instant<UTC>(try JulianDate(year: 1950, month: 1, day: 1)), to: Instant<UTC>(try JulianDate(year: 1951, month: 1, day: 1)), precision: .arcsecond)
		}
	}

	@Test func endOfTheCoverage() throws {
		// An eclipse whose last contact is 5 minutes before the end of the coverage is found,
		// though the samples that bracket its contacts run past it, and one whose last contact
		// is past it isn't: a total eclipse and a partial one.
		let total = try Sun.nextEclipse(after: Instant<TT>(try JulianDate(year: 2024, month: 4, day: 1)), precision: .arcsecond)
		let partial = try Sun.nextEclipse(after: Instant<TT>(try JulianDate(year: 2025, month: 3, day: 1)), precision: .arcsecond)
		#expect(total.kind == .total && partial.kind == .partial)
		for eclipse in [total, partial] {
			let from = Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(days: -10))
			let end = eclipse.partialPhase.upperBound
			let covered = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try end.julianDate.adding(seconds: 300)))
			let found = try Sun.nextEclipse(by: .moon, after: from, ephemeris: covered)
			#expect(try Self.same(found, eclipse))
			#expect(abs(try Self.seconds(from: found.partialPhase.upperBound, to: end)) < 0.2)
			let inInterval = try Sun.eclipses(by: .moon, from: from, to: Instant<TT>(try eclipse.greatestEclipse.julianDate.adding(seconds: 60)), ephemeris: covered)
			#expect(try inInterval.count == 1 && Self.same(inInterval[0], eclipse))
			let short = try TruncatedEphemeris(BuiltInEphemeris(precision: .arcsecond), endingAt: Instant(try end.julianDate.adding(seconds: -60)))
			#expect(throws: Sun.EclipseError.ephemeris(.outsideCoverage)) { try Sun.nextEclipse(by: .moon, after: from, ephemeris: short) }
		}
	}

	@Test func ellipse() {
		// The distance from a circle, and from an ellipse along its axes and off them
		#expect(abs(signedDistanceFromEllipse(x: 3, y: 4, b: 1) - 4) < 1e-12)
		#expect(abs(signedDistanceFromEllipse(x: 0.3, y: 0.4, b: 1) + 0.5) < 1e-12)
		#expect(abs(signedDistanceFromEllipse(x: 0, y: 1.5, b: 0.99) - 0.51) < 1e-12)
		#expect(abs(signedDistanceFromEllipse(x: -1.5, y: 0, b: 0.99) - 0.5) < 1e-12)
		// Off the axes, the nearest point is where the line from the point is normal to the
		// ellipse.
		let (x, y, b) = (1.2, 0.9, 0.996)
		let distance = signedDistanceFromEllipse(x: x, y: y, b: b)
		var best = Double.infinity
		for step in 0 ..< 200_000 {
			let theta = Double(step) / 200_000 * 2 * .pi
			best = min(best, ((x - Math.cos(theta)) * (x - Math.cos(theta)) + (y - b * Math.sin(theta)) * (y - b * Math.sin(theta))).squareRoot())
		}
		#expect(distance > 0 && abs(distance - best) < 1e-9)
	}
}
