//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

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
