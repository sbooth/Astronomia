//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The place of a body corrected for light time only, as astrometric catalogs give places.
///
/// The position is the body's place, relative to the observer, when the light now seen left
/// it: its direction and its distance at that time. It is in the axes of the ICRS, or of another
/// fixed frame, and has neither gravitational deflection nor aberration, so it can be compared
/// with the places of stars in a catalog. For where the body appears in the sky, use an
/// ``ApparentPlace``.
public struct AstrometricPlace<Frame: FixedReferenceFrame>: Hashable, Sendable {
	/// The position relative to the observer.
	public let position: Position<Frame>
	/// The time the light took to reach the observer.
	public let lightTime: DayInterval
	/// The instant of observation.
	public let instant: Instant<TT>

	/// Creates an astrometric place.
	init(position: Position<Frame>, lightTime: DayInterval, instant: Instant<TT>) {
		self.position = position
		self.lightTime = lightTime
		self.instant = instant
	}

	/// Returns the same place in another fixed frame.
	///
	/// - Parameter frame: The frame to express the place in.
	/// - Returns: The place in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type) -> AstrometricPlace<Target> {
		AstrometricPlace<Target>(position: position.converted(to: frame), lightTime: lightTime, instant: instant)
	}
}
