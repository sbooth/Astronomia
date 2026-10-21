//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The mean ecliptic and equinox of J2000.0, as defined by the IAU 2006 precession.
///
/// The x axis points to the mean equinox of J2000.0 and the z axis to the north pole of the
/// mean ecliptic of J2000.0. The frame is the ICRS rotated by the frame bias and the
/// obliquity of the ecliptic at J2000.0, 84,381.406".
///
/// - Note: The planetary and lunar theories each refer to their own realization of the
///   J2000 ecliptic, which differs from this one by milliarcseconds, such as
///   ``VSOP2013/Ecliptic``. Their positions convert to this frame through the ICRS.
public enum EclipticJ2000: EclipticFrame, FixedReferenceFrame {
	public static let name = "Ecliptic J2000"

	/// The IAU 2006 Fukushima-Williams angles at J2000.0: γ̄ = -0.052928",
	/// φ̄ = 84,381.412819", and ψ̄ = -0.041775", giving R3(-ψ̄) R1(φ̄) R3(γ̄).
	public static let rotationFromICRS = Rotation<ICRS, EclipticJ2000>.aboutZ(Angle(arcseconds: 0.041_775))
		* Rotation<ICRS, ICRS>.aboutX(Angle(arcseconds: 84_381.412_819))
		* Rotation<ICRS, ICRS>.aboutZ(Angle(arcseconds: -0.052_928))
}
