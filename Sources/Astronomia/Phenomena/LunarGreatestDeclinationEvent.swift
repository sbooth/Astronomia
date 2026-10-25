//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A greatest declination of the Moon: an instant when the Moon's apparent geocentric
/// declination is farthest north or south in its monthly swing across the equator.
///
/// ```swift
/// let events = try LunarGreatestDeclinations.events(from: start, to: end)
/// for event in events where event.kind == .north {
/// 	print(event.instant, event.declination.degrees)
/// }
/// ```
public struct LunarGreatestDeclinationEvent: Hashable, Sendable {
	/// The side of the equator of a greatest declination.
	public enum Kind: Hashable, Sendable, CaseIterable {
		/// The greatest northern declination, a maximum of the declination.
		case north
		/// The greatest southern declination, a minimum of the declination.
		case south
	}

	/// The side of the equator.
	public let kind: Kind
	/// The instant of the greatest declination.
	public let instant: Instant<TT>
	/// The Moon's apparent declination at the instant, in the true equator and equinox of date.
	///
	/// Over the 18.6-year cycle of the Moon's nodes, the greatest declinations range from
	/// about 18.1° to 28.7° north or south.
	public let declination: Angle

	/// Creates an event.
	init(kind: Kind, instant: Instant<TT>, declination: Angle) {
		self.kind = kind
		self.instant = instant
		self.declination = declination
	}
}
