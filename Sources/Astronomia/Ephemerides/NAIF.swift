//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// NAIF IDs, the numbers of bodies in JPL's ephemerides and SPICE, and the bodies' radii.
enum NAIF {
	/// Returns the radius of a body by its NAIF ID.
	///
	/// The radii are the Sun's nominal radius of IAU 2015 Resolution B3, the Moon's mean
	/// radius, the Earth's WGS84 equatorial radius, and the other planets' equatorial radii
	/// from the IAU Working Group on Cartographic Coordinates and Rotational Elements, 2015
	/// (Archinal et al. 2018), for the gas giants at the 1 bar level. The barycenters of the
	/// planets' systems, 1 to 9, take their planets' radii, except the Earth-Moon barycenter,
	/// which is a point, as is the solar system barycenter, 0.
	///
	/// - Parameter naifID: The body's NAIF ID.
	/// - Returns: The radius, or `nil` for a point or a body not in the table.
	static func radius(of naifID: Int) -> Distance? {
		switch naifID {
		case 10: nominalSolarRadius
		case 1, 199: .kilometers(2_440.53)
		case 2, 299: .kilometers(6_051.8)
		case 399: earthEquatorialRadius
		case 301: lunarMeanRadius
		case 4, 499: .kilometers(3_396.19)
		case 5, 599: jupiterEquatorialRadius
		case 6, 699: saturnEquatorialRadius
		case 7, 799: .kilometers(25_559)
		case 8, 899: .kilometers(24_764)
		case 9, 999: .kilometers(1_188.3)
		default: nil
		}
	}
}
