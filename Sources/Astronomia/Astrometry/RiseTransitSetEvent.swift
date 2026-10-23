//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An event of a target's daily path across the sky of a site: its rising or setting through an
/// ``EventAltitude``, or its transit of the meridian.
///
/// ```swift
/// let events = try site.riseTransitSetEvents(of: .sun, from: start, to: end)
/// for event in events where event.kind == .rising {
/// 	print(event.instant, event.place.azimuth.degrees)
/// }
/// ```
public struct RiseTransitSetEvent: Hashable, Sendable {
	/// A kind of event.
	public enum Kind: Hashable, Sendable, CaseIterable {
		/// The target rises through the event altitude.
		case rising
		/// The target sets through the event altitude.
		case setting
		/// The target crosses the meridian above the pole, at hour angle 0°, near its highest.
		case upperTransit
		/// The target crosses the meridian below the pole, at hour angle 180°, near its lowest.
		case lowerTransit
	}

	/// The kind of event.
	public let kind: Kind
	/// The instant of the event.
	public let instant: Instant<TT>
	/// The target's place at the instant, without refraction: its azimuth at rising or setting,
	/// or its altitude at transit.
	public let place: ObservedPlace

	/// Creates an event.
	init(kind: Kind, instant: Instant<TT>, place: ObservedPlace) {
		self.kind = kind
		self.instant = instant
		self.place = place
	}
}
