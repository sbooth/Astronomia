//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

@testable import Astronomia

/// Values at the 99 dates of VSOP2013.ctl, from JD 2411545.0 TDB in steps of 4,000 days.
///
/// `elements`, `position`, and `velocity` are the built-in, truncated series evaluated
/// independently in Python from the generated C data. The `check` values are VSOP2013.ctl,
/// from the full series: the elements, then the ecliptic and ICRS positions and velocities.
struct VSOP2013CheckValue {
	let body: VSOP2013.Body
	/// The Julian day number of the TDB date, at noon.
	let julianDayNumber: Int
	let elements: [Double]
	let position: [Double]
	let velocity: [Double]
	let checkElements: [Double]
	let checkEcliptic: [Double]
	let checkICRS: [Double]

	init(_ body: VSOP2013.Body, _ julianDayNumber: Int, elements: [Double], position: [Double], velocity: [Double], checkElements: [Double], checkEcliptic: [Double], checkICRS: [Double]) {
		self.body = body
		self.julianDayNumber = julianDayNumber
		self.elements = elements
		self.position = position
		self.velocity = velocity
		self.checkElements = checkElements
		self.checkEcliptic = checkEcliptic
		self.checkICRS = checkICRS
	}
}

let vsop2013CheckValues: [VSOP2013CheckValue] = textFixture("Vsop2013CheckValues") { row in
	VSOP2013CheckValue(row.value(), row.int(), elements: row.doubles(6), position: row.vector(), velocity: row.vector(), checkElements: row.doubles(6), checkEcliptic: row.doubles(6), checkICRS: row.doubles(6))
}
