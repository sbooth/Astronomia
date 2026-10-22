//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The International Celestial Reference System.
///
/// The axes are fixed by the positions of extragalactic radio sources, and lie within 0.1" of
/// the mean equator and equinox of J2000.0. The ICRS axes are also those of the barycentric
/// (BCRS) and geocentric (GCRS) celestial reference systems.
public enum ICRS: EquatorialFrame, FixedReferenceFrame {
	public static let name = "ICRS"

	/// The identity.
	public static let rotationFromICRS = Rotation<ICRS, ICRS>.identity
}
