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
///
/// A frame is fixed relative to the ICRS, a ``FixedReferenceFrame``; a celestial frame of date,
/// a ``DatedReferenceFrame``, whose axes also depend on an instant, its epoch; or a frame that
/// turns with the Earth, a ``TerrestrialReferenceFrame``.
public protocol ReferenceFrame: Sendable {
	/// The kind of epoch that fixes the frame's axes along with its definition: ``NoEpoch``
	/// for a frame that needs none, such as a fixed frame or the ``ITRS``, or an instant for a
	/// frame of date.
	associatedtype Epoch: Hashable & Sendable = NoEpoch

	/// The conventional name of the frame, such as `"ICRS"`.
	static var name: String { get }
}

/// The epoch of a frame that needs none, such as a frame fixed relative to the ICRS or to the
/// Earth.
public struct NoEpoch: Hashable, Sendable {
	/// Creates the empty epoch.
	init() {}
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
public protocol FixedReferenceFrame: ReferenceFrame where Epoch == NoEpoch {
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

/// A frame whose axes depend on an instant, its epoch, such as the true equator and equinox
/// of a date.
///
/// Positions, velocities, state vectors, and spherical positions in a frame of date carry
/// the frame's epoch, and are created with it. Values at different epochs are in different
/// frames, so the operations that combine them, or rotate one with a rotation for an epoch,
/// throw ``CoordinateError/epochMismatch`` when the epochs differ. The epoch is in TT, the
/// time argument of precession and nutation.
///
/// A frame of date turns slowly, so a velocity in it is the rotated inertial velocity; the
/// rate of the frame's own rotation, below one part in 10⁹, is left out.
public protocol DatedReferenceFrame: ReferenceFrame where Epoch == Instant<TT> {
	/// Returns the rotation from ICRS axes to this frame's axes at an epoch.
	///
	/// - Parameters:
	///   - epoch: The epoch of the frame.
	///   - earthOrientation: Observed Earth orientation to apply, for frames that use it.
	/// - Returns: The rotation, whose `To` epoch is `epoch`.
	static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, Self>
}

extension DatedReferenceFrame {
	/// Returns the rotation from ICRS axes to this frame's axes at an epoch, from the models
	/// alone.
	///
	/// - Parameter epoch: The epoch of the frame.
	/// - Returns: The rotation, whose `To` epoch is `epoch`.
	public static func rotationFromICRS(at epoch: Instant<TT>) -> Rotation<ICRS, Self> {
		rotationFromICRS(at: epoch, earthOrientation: .model)
	}

	/// Returns the rotation from this frame's axes at an epoch to a fixed frame's axes.
	///
	/// ```swift
	/// let rotation = TrueEquatorOfDate.rotation(from: tt, to: ICRS.self)
	/// ```
	///
	/// - Parameters:
	///   - epoch: The epoch of this frame.
	///   - frame: The frame to rotate to.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: FixedReferenceFrame>(from epoch: Instant<TT>, to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> Rotation<Self, Target> {
		Target.rotationFromICRS * rotationFromICRS(at: epoch, earthOrientation: earthOrientation).inverse
	}

	/// Returns the rotation from this frame's axes at an epoch to a frame of date's axes at
	/// another, or the same, epoch.
	///
	/// - Parameters:
	///   - epoch: The epoch of this frame.
	///   - frame: The frame to rotate to.
	///   - targetEpoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: DatedReferenceFrame>(from epoch: Instant<TT>, to frame: Target.Type, at targetEpoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Rotation<Self, Target> {
		Target.rotationFromICRS(at: targetEpoch, earthOrientation: earthOrientation) * rotationFromICRS(at: epoch, earthOrientation: earthOrientation).inverse
	}
}

extension FixedReferenceFrame {
	/// Returns the rotation from this frame's axes to a frame of date's axes at an epoch.
	///
	/// To convert many values to a frame of date at one epoch, compute the rotation once and
	/// apply it to each with `*`.
	///
	/// ```swift
	/// let rotation = ICRS.rotation(to: TrueEquatorOfDate.self, at: tt)
	/// ```
	///
	/// - Parameters:
	///   - frame: The frame to rotate to.
	///   - epoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: DatedReferenceFrame>(to frame: Target.Type, at epoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Rotation<Self, Target> {
		Target.rotationFromICRS(at: epoch, earthOrientation: earthOrientation) * rotationFromICRS.inverse
	}
}

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

/// A frame that turns with the Earth, such as the ``ITRS`` or a horizon frame at a site.
///
/// Its orientation relative to the ICRS depends on the instant in TT, for precession and
/// nutation, and in UT1, for the Earth's rotation. Converting to or from it needs both, so
/// conversions that find UT1 from TT, or TT from UT1, throw a ``TimescaleConversionError`` when
/// they can't. The frame turns at about 15° an hour, so a state vector converts with the
/// velocity of the frame's rotation, ω × r, as well as the rotation of its velocity; a
/// velocity alone, without a position, does not convert. The slower turning of the pole by
/// precession, nutation, and polar motion, about 1e-7 of the Earth's rotation, is left out.
///
/// A frame of your own fixed to the Earth, with ``NoEpoch``, conforms by composing a rotation
/// from the ``ITRS``, built with ``Rotation/aboutX(_:)``, ``Rotation/aboutY(_:)``, and
/// ``Rotation/aboutZ(_:)``, with `ITRS.rotationFromICRS(at:ut1:earthOrientation:)`, and
/// rotating the ITRS angular velocity into its axes.
public protocol TerrestrialReferenceFrame: ReferenceFrame {
	/// Returns the rotation from ICRS axes to this frame's axes at an instant.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - ut1: The same instant in UT1.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, whose `To` epoch, if the frame has one, is `tt`.
	static func rotationFromICRS(at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> Rotation<ICRS, Self>

	/// Returns the angular velocity of this frame relative to the ICRS at an instant, in this
	/// frame's axes.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The angular velocity, in radians per day.
	static func angularVelocity(at tt: Instant<TT>, earthOrientation: EarthOrientation) -> SIMD3<Double>
}

extension TerrestrialReferenceFrame {
	/// Returns the rotation from ICRS axes to this frame's axes at a TT instant, finding UT1
	/// from the Earth orientation.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The rotation, whose `To` epoch, if the frame has one, is `tt`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public static func rotationFromICRS(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Rotation<ICRS, Self> {
		let ut1 = try tt.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return rotationFromICRS(at: tt, ut1: ut1, earthOrientation: earthOrientation)
	}
}
