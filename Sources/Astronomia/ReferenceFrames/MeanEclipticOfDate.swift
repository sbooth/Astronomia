//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

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
