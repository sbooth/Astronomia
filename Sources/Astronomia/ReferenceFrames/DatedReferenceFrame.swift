//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

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
