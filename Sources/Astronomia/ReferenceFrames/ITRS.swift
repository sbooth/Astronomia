//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The International Terrestrial Reference System (ITRS).
///
/// The frame is fixed to the Earth's crust, as the ITRF realizes it: the z axis points near
/// the mean pole of 1900–1905 and the x axis to the meridian of Greenwich. It is the ``TIRS``
/// rotated by polar motion, W = R1(-y_p) R2(-x_p) R3(s'), with x_p and y_p from the Earth
/// orientation's table, or zero without it. Longitude and latitude in the frame are the
/// geocentric east longitude and latitude.
///
/// It has no epoch: a position fixed to the Earth keeps its coordinates.
public enum ITRS: TerrestrialReferenceFrame {
	public static let name = "ITRS"

	public static func rotationFromICRS(at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> Rotation<ICRS, ITRS> {
		let polarMotion = IAU2006.polarMotion(at: tt, earthOrientation: earthOrientation)
		let rotation = polarMotion * IAU2006.terrestrialIntermediate(at: tt, ut1: ut1, earthOrientation: earthOrientation)
		return rotation.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: NoEpoch())
	}

	/// Returns the Earth's angular velocity, along the CIP, in ITRS axes.
	public static func angularVelocity(at tt: Instant<TT>, earthOrientation: EarthOrientation) -> SIMD3<Double> {
		let axis = IAU2006.polarMotion(at: tt, earthOrientation: earthOrientation).storage
		let rate = earthOrientation.rotationRate(at: tt)
		return SIMD3(axis.0.z, axis.1.z, axis.2.z) * rate
	}
}
