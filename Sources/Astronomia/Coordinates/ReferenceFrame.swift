//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The orientation of a set of coordinate axes.
///
/// Conforming types are caseless enums used only as type-level tags for ``Position`` and
/// ``Rotation``, as timescales are for ``Instant``. A frame fixes the directions of the axes,
/// not the origin: the same frame serves barycentric, heliocentric, and geocentric
/// positions.
public protocol ReferenceFrame: Sendable {
	/// The conventional name of the frame, such as `"ICRS"`.
	static var name: String { get }
}

/// A frame whose fundamental plane is an equator, with longitude measured as right
/// ascension and latitude as declination.
public protocol EquatorialFrame: ReferenceFrame {}

/// A frame whose fundamental plane is an ecliptic, with longitude and latitude measured as
/// ecliptic longitude and latitude.
public protocol EclipticFrame: ReferenceFrame {}

/// A frame fixed relative to the ICRS, independent of time.
///
/// Positions convert between fixed frames with ``Position/converted(to:)``. A frame of your
/// own, such as galactic coordinates, conforms by composing its rotation from the ICRS out of
/// ``Rotation/aboutX(_:)``, ``Rotation/aboutY(_:)``, and ``Rotation/aboutZ(_:)``.
public protocol FixedReferenceFrame: ReferenceFrame {
	/// The rotation from ICRS axes to this frame's axes.
	static var rotationFromICRS: Rotation<ICRS, Self> { get }
}

extension FixedReferenceFrame {
	/// Returns the rotation from this frame's axes to another fixed frame's axes.
	///
	/// ```swift
	/// let rotation = ICRS.rotation(to: EclipticJ2000.self)
	/// ```
	///
	/// - Parameter frame: The frame to rotate to.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: FixedReferenceFrame>(to frame: Target.Type) -> Rotation<Self, Target> {
		Target.rotationFromICRS * rotationFromICRS.inverse
	}
}

/// The International Celestial Reference System.
///
/// The axes are fixed by the positions of extragalactic radio sources, and lie within 0.1″ of
/// the mean equator and equinox of J2000.0. The ICRS axes are also those of the barycentric
/// (BCRS) and geocentric (GCRS) celestial reference systems.
public enum ICRS: EquatorialFrame, FixedReferenceFrame {
	public static let name = "ICRS"

	/// The identity.
	public static let rotationFromICRS = Rotation<ICRS, ICRS>.identity
}

/// The mean ecliptic and equinox of J2000.0, as defined by the IAU 2006 precession.
///
/// The x axis points to the mean equinox of J2000.0 and the z axis to the north pole of the
/// mean ecliptic of J2000.0. The frame is the ICRS rotated by the frame bias and the
/// obliquity of the ecliptic at J2000.0, 84,381.406″.
///
/// - Note: The planetary and lunar theories each refer to their own realization of the
///   J2000 ecliptic, which differs from this one by milliarcseconds. Their positions are
///   rotated to the ICRS by each theory's own transformation, so they do not depend on this
///   frame.
public enum EclipticJ2000: EclipticFrame, FixedReferenceFrame {
	public static let name = "Ecliptic J2000"

	/// The IAU 2006 Fukushima-Williams angles at J2000.0: γ̄ = -0.052928″,
	/// φ̄ = 84,381.412819″, and ψ̄ = -0.041775″, giving R3(-ψ̄) R1(φ̄) R3(γ̄).
	public static let rotationFromICRS = Rotation<ICRS, EclipticJ2000>.aboutZ(Angle(arcseconds: 0.041_775))
		* Rotation<ICRS, ICRS>.aboutX(Angle(arcseconds: 84_381.412_819))
		* Rotation<ICRS, ICRS>.aboutZ(Angle(arcseconds: -0.052_928))
}
