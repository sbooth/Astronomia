//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The place where a body or a star appears to the observer: corrected for light time, the
/// gravitational deflection of light, and aberration.
///
/// The position is the apparent direction with the target's distance when the light left it.
/// For a ``Star`` the light time is its distance over c, years or more, and nominal for a star
/// without a parallax.
/// It begins in the axes of the ICRS, as the geocentric place in the GCRS, and converts to a
/// frame of date at its own instant: to ``TrueEquatorOfDate`` for the classical apparent right
/// ascension and declination, or to ``CIRS`` for the intermediate place.
///
/// ```swift
/// let place = try Observer.geocenter.apparentPlace(of: .mars, at: instant)
/// let ofDate = place.converted(to: TrueEquatorOfDate.self).position.spherical
/// ```
public struct ApparentPlace<Frame: ReferenceFrame>: Hashable, Sendable {
	/// The position relative to the observer.
	public let position: Position<Frame>
	/// The time the light took to reach the observer.
	public let lightTime: DayInterval
	/// The instant of observation, which is also the epoch of a frame of date.
	public let instant: Instant<TT>

	/// Creates an apparent place.
	init(position: Position<Frame>, lightTime: DayInterval, instant: Instant<TT>) {
		self.position = position
		self.lightTime = lightTime
		self.instant = instant
	}
}

extension ApparentPlace where Frame: FixedReferenceFrame {
	/// Returns the same place in another fixed frame.
	///
	/// - Parameter frame: The frame to express the place in.
	/// - Returns: The place in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type) -> ApparentPlace<Target> {
		ApparentPlace<Target>(position: position.converted(to: frame), lightTime: lightTime, instant: instant)
	}

	/// Returns the same place in a frame of date at the instant of observation.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the place in.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The place in `frame`, whose epoch is the place's instant.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> ApparentPlace<Target> {
		ApparentPlace<Target>(position: position.converted(to: frame, at: instant, earthOrientation: earthOrientation), lightTime: lightTime, instant: instant)
	}
}

extension ApparentPlace where Frame: DatedReferenceFrame {
	/// Returns the same place in a fixed frame.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the place in.
	///   - earthOrientation: Observed Earth orientation to apply, which should be that the
	///     place was converted to this frame with.
	/// - Returns: The place in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> ApparentPlace<Target> {
		ApparentPlace<Target>(position: position.converted(to: frame, earthOrientation: earthOrientation), lightTime: lightTime, instant: instant)
	}

	/// Returns the same place in another frame of date at the instant of observation.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the place in.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The place in `frame`, whose epoch is the place's instant.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> ApparentPlace<Target> {
		ApparentPlace<Target>(position: position.converted(to: frame, at: instant, earthOrientation: earthOrientation), lightTime: lightTime, instant: instant)
	}
}
