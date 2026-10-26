//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// DE421: barycentric positions, in km, and velocities, in km/day, in the ICRF at 0h TDB.
let de421States: [(julianDate: Double, naifID: Int, position: [Double], velocity: [Double])] = textFixture("De421States") { row in
	(row.double(), row.int(), row.vector(), row.vector())
}
