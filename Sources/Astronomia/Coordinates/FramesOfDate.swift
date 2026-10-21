//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

// The celestial frames of date of the IAU 2006 precession and IAU 2000A_R06 nutation, as
// defined in the IERS Conventions (2010), Chapter 5. Their epochs are in TT.

/// The mean equator and equinox of date.
///
/// The z axis points to the mean pole of date, which precesses but does not nutate, and the
/// x axis to the mean equinox of date. The frame is the ICRS rotated by the frame bias and the
/// IAU 2006 precession.
public enum MeanEquatorOfDate: EquatorialFrame, DatedReferenceFrame {
	public static let name = "Mean equator of date"

	/// Returns the frame bias and precession at an epoch. Earth orientation is not used.
	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, MeanEquatorOfDate> {
		let angles = IAU2006.precessionAngles(at: epoch.julianDate.julianCenturiesSinceJ2000)
		return IAU2006.biasPrecession(angles: angles).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

/// The true equator and equinox of date.
///
/// The z axis points to the celestial intermediate pole (CIP), which precesses and nutates,
/// and the x axis to the true equinox of date, where the ecliptic of date crosses the true
/// equator. Right ascensions in this frame are those of almanacs "of date" and of Greenwich
/// apparent sidereal time. The frame is the ICRS rotated by the frame bias, the IAU 2006
/// precession, and the IAU 2000A_R06 nutation, corrected by the celestial pole offsets of the
/// Earth orientation context.
public enum TrueEquatorOfDate: EquatorialFrame, DatedReferenceFrame {
	public static let name = "True equator of date"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TrueEquatorOfDate> {
		let orientation = IAU2006.Orientation(at: epoch.julianDate.julianCenturiesSinceJ2000, poleOffsets: earthOrientation.poleOffsets(at: epoch))
		return orientation.trueEquator.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

/// The Celestial Intermediate Reference System (CIRS).
///
/// The z axis points to the celestial intermediate pole (CIP), as in ``TrueEquatorOfDate``,
/// and the x axis to the celestial intermediate origin (CIO), a point on the CIP's equator
/// that does not rotate about the pole as the pole moves. Right ascensions in this frame
/// differ from those of the true equinox by the equation of the origins, and the hour angle
/// is the Earth rotation angle less the right ascension. The IAU adopted the CIO in 2000 and
/// named the system in 2006 (Resolution B2).
///
/// - Note: Here a frame is only a set of axes. Libraries such as Astropy also use the name
///   for apparent places, which include aberration and light deflection.
public enum CIRS: EquatorialFrame, DatedReferenceFrame {
	public static let name = "CIRS"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, CIRS> {
		let orientation = IAU2006.Orientation(at: epoch.julianDate.julianCenturiesSinceJ2000, poleOffsets: earthOrientation.poleOffsets(at: epoch))
		return orientation.intermediate.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

/// The mean ecliptic and equinox of date.
///
/// The z axis points to the pole of the ecliptic of date and the x axis to the mean equinox of
/// date. The frame is the ``MeanEquatorOfDate`` rotated by the mean obliquity, R1(ε_A).
public enum MeanEclipticOfDate: EclipticFrame, DatedReferenceFrame {
	public static let name = "Mean ecliptic of date"

	/// Returns the rotation at an epoch. Earth orientation is not used.
	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, MeanEclipticOfDate> {
		let angles = IAU2006.precessionAngles(at: epoch.julianDate.julianCenturiesSinceJ2000)
		return IAU2006.meanEcliptic(angles: angles).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}

/// The ecliptic of date with the true equinox of date.
///
/// The z axis points to the pole of the ecliptic of date, as in ``MeanEclipticOfDate``, which
/// nutation does not move, and the x axis to the true equinox of date. Ecliptic longitudes
/// in this frame are the mean longitudes plus the nutation in longitude, as for the apparent
/// longitude of the Sun at the equinoxes and solstices. The frame is the
/// ``TrueEquatorOfDate`` rotated by the true obliquity, R1(ε_A + Δε).
public enum TrueEclipticOfDate: EclipticFrame, DatedReferenceFrame {
	public static let name = "True ecliptic of date"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TrueEclipticOfDate> {
		let orientation = IAU2006.Orientation(at: epoch.julianDate.julianCenturiesSinceJ2000, poleOffsets: earthOrientation.poleOffsets(at: epoch))
		return orientation.trueEcliptic.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}
