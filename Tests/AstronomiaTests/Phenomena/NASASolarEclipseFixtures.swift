//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

@testable import Astronomia

/// The eclipses of the Sun from 2001 to 2100 of the Five Millennium Catalog of Solar Eclipses
/// (Espenak and Meeus, NASA TP-2006-214141), with the VSOP87 and ELP-2000/82 theories: the
/// Gregorian date and the TT of greatest eclipse, to the second, ΔT, in seconds, the lunation and
/// the saros, the kind, the qualifier of the kind, or `nil` for none, gamma, the magnitude, the
/// latitude and longitude of greatest eclipse, in degrees, north and east positive, the Sun's
/// altitude there, in degrees, the width of the path, in km, and the duration of the central
/// phase on the central line, in seconds, from
/// https://eclipse.gsfc.nasa.gov/SEcat5/SE2001-2100.html.
///
/// The qualifiers are `m`, the middle eclipse of its saros; `n` and `s`, a central eclipse with
/// no northern or southern limit; `+` and `-`, an eclipse that isn't central, with no northern
/// or southern limit; `2` and `3`, a hybrid eclipse that begins total and ends annular, or the
/// reverse; and `b` and `e`, the first or last eclipse of its saros.
///
/// Eclipse Predictions by Fred Espenak, NASA's GSFC.
let nasaSolarEclipses: [(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, deltaT: Double, lunation: Int, saros: Int, kind: Sun.Eclipse.Kind, qualifier: Character?, gamma: Double, magnitude: Double, latitude: Double, longitude: Double, sunAltitude: Double, pathWidth: Double?, centralDuration: Double?)] = textFixture("NASASolarEclipses") { row in
	let date = (row.int(), row.int(), row.int(), row.int(), row.int(), row.int())
	let (deltaT, lunation, saros) = (row.double(), row.int(), row.int())
	let kind: Sun.Eclipse.Kind = row.value()
	let qualifier = row.field()
	return (date.0, date.1, date.2, date.3, date.4, date.5, deltaT, lunation, saros, kind, qualifier == "nil" ? nil : qualifier.first, row.double(), row.double(), row.double(), row.double(), row.double(), row.optionalDouble(), row.optionalDouble())
}
