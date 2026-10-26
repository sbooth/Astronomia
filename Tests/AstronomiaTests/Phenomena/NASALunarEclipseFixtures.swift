//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

@testable import Astronomia

/// The eclipses of the Moon from 2001 to 2049 of the Five Millennium Catalog of Lunar Eclipses
/// (Espenak and Meeus, NASA TP-2009-214173), with the JPL DE406 ephemeris and the shadow enlarged
/// by Danjon's method: the Gregorian date and the TT of greatest eclipse, to the second, the kind,
/// gamma, the penumbral and umbral magnitudes, and the durations of the penumbral, partial, and
/// total phases, in minutes, from https://eclipse.gsfc.nasa.gov/LEcat5/LE2001-2100.html.
///
/// Eclipse Predictions by Fred Espenak, NASA's GSFC.
let nasaLunarEclipses: [(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, kind: Moon.Eclipse.Kind, gamma: Double, penumbralMagnitude: Double, umbralMagnitude: Double, penumbral: Double, partial: Double?, total: Double?)] = textFixture("NASALunarEclipses") { row in
	(row.int(), row.int(), row.int(), row.int(), row.int(), row.int(), row.value(), row.double(), row.double(), row.double(), row.double(), row.optionalDouble(), row.optionalDouble())
}
