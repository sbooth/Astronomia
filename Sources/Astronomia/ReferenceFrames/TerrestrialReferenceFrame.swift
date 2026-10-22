//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A frame that turns with the Earth, such as the ``ITRS`` or a horizon frame at a site.
///
/// The IERS Conventions (2010), Chapter 5, relate the celestial and terrestrial systems by
/// GCRS → ``CIRS`` → (Earth rotation angle) → ``TIRS`` → (polar motion) → ``ITRS``.
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
/// rotating the ITRS angular velocity into its axes. A frame with an epoch gives its rotation
/// the epoch with ``Rotation/relabeled(fromFrameEpoch:toFrameEpoch:)``.
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
