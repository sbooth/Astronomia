//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A passage of the Moon through a node of its orbit: an instant when the Moon's apparent
/// geocentric ecliptic latitude is zero, as it crosses the ecliptic northward or southward.
///
/// ```swift
/// let events = try LunarNodes.events(from: start, to: end)
/// for event in events where event.kind == .ascending {
/// 	print(event.instant, event.longitude.degrees)
/// }
/// ```
public struct LunarNodeEvent: Hashable, Sendable {
	/// A node.
	public enum Kind: Hashable, Sendable, CaseIterable {
		/// The ascending node: the Moon crosses the ecliptic northward.
		case ascending
		/// The descending node: the Moon crosses the ecliptic southward.
		case descending
	}

	/// The node.
	public let kind: Kind
	/// The instant of the passage.
	public let instant: Instant<TT>
	/// The Moon's apparent ecliptic longitude at the instant, the longitude of the node, in the
	/// true ecliptic and equinox of date, in the right-open interval [0, 360)°.
	///
	/// The nodes regress, moving westward around the ecliptic once in about 18.6 years, so the
	/// longitude of each ascending node is about 1.4° less than the last.
	public let longitude: Angle

	/// Creates an event.
	init(kind: Kind, instant: Instant<TT>, longitude: Angle) {
		self.kind = kind
		self.instant = instant
		self.longitude = longitude
	}
}
