//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

@testable import Astronomia

/// The two fits of ELP/MPP02 as values, for the fixtures.
enum ELPFit: CaseIterable {
	case laserRanging
	case de405

	/// The fit's series.
	var series: ELPMPP02.FittedSeries {
		switch self {
		case .laserRanging: ELPMPP02.LaserRanging.fittedSeries
		case .de405: ELPMPP02.DE405.fittedSeries
		}
	}

	/// Returns the Moon's geocentric state from the series, in the frame and units of
	/// `ELPMPP02.for`: kilometers and kilometers per day in the fit's ecliptic.
	///
	/// - Parameter days: TDB in days from J2000.0.
	func seriesState(at days: Double) -> (position: Vector3, velocity: Vector3) {
		series.state(at: days / daysPerJulianCentury)
	}

	/// Returns the Moon's geocentric state in the fit's ecliptic.
	func eclipticState(at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		switch self {
		case .laserRanging: ELPMPP02.LaserRanging.eclipticState(at: tdb)
		case .de405: ELPMPP02.DE405.eclipticState(at: tdb)
		}
	}

	/// Returns a vector in the fit's ecliptic in the ICRS.
	func icrs(_ vector: Vector3) -> Vector3 {
		switch self {
		case .laserRanging: ELPMPP02.LaserRanging.Ecliptic.rotation(to: ICRS.self).apply(to: vector)
		case .de405: ELPMPP02.DE405.Ecliptic.rotation(to: ICRS.self).apply(to: vector)
		}
	}

	/// Returns the Moon's geocentric state in the ICRS.
	func icrsState(at tdb: JulianDate) -> (position: Vector3, velocity: Vector3)? {
		switch self {
		case .laserRanging: ELPMPP02.laserRanging.icrsState(at: tdb)
		case .de405: ELPMPP02.de405.icrsState(at: tdb)
		}
	}
}

/// ELPMPP02.TXT: positions, in km, and velocities, in km/day, of the full series in the fit's
/// ecliptic, from ELPMPP02.for. The first 21 are fitted to LLR, the rest to DE405.
let elpmpp02CheckValues: [(fit: ELPFit, julianDate: Double, position: [Double], velocity: [Double])] = textFixture("Elpmpp02CheckValues") { row in
	(row.value(), row.double(), row.vector(), row.vector())
}

/// The built-in series evaluated by an independent implementation that sums them in the order
/// of ELPMPP02.for, with the rate of the distance scaled as the distance is: days from J2000.0
/// TDB, position in km, velocity in km/day.
let elpmpp02Reference: [(fit: ELPFit, days: Double, position: [Double], velocity: [Double])] = textFixture("Elpmpp02Reference") { row in
	(row.value(), row.double(), row.vector(), row.vector())
}

/// DE421: the geocentric Moon in the ICRF at 0h TDB, in km, an independent check of the frame.
let de421Moon: [(julianDate: Double, position: [Double])] = [
	(2433282.5, [186511.6745363558, 312836.78945146, 164402.43937867452]),
	(2436935.0, [273457.93135054875, -233968.14223735404, -78567.60382952623]),
	(2440587.5, [-384373.06675918994, -63032.03350259498, -44389.491001159106]),
	(2444240.0, [-68.9918784373981, 365692.5225178523, 125793.78573320327]),
	(2447892.5, [318120.5040047305, -194145.51638753712, -77831.17029084695]),
	(2451545.0, [-291608.3853096409, -266716.8329467875, -76102.4871467836]),
	(2455197.5, [-81376.4337799175, 319318.1855750719, 143383.7968213082]),
	(2458850.0, [398673.02258135815, -38480.994607969486, -55662.80602765297]),
	(2462502.5, [-193071.6013759011, -277242.344249639, -136882.89373363237]),
	(2466155.0, [-210912.45486300904, 303895.9295074842, 162151.9970044198]),
	(2469807.5, [359580.59872872854, 98050.66809861243, 66910.92409300982]),
]
