//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

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
