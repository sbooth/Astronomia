//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An equinox or a solstice: an instant when the Sun's apparent geocentric ecliptic longitude
/// is a multiple of 90°.
///
/// The kinds are named for their months, which are the same in both hemispheres; the March
/// equinox begins spring in the northern hemisphere and autumn in the southern.
///
/// ```swift
/// for event in try Seasons.events(from: start, to: end) {
/// 	print(event.kind, event.instant)
/// }
/// ```
public struct SeasonEvent: Hashable, Sendable {
	/// An equinox or a solstice.
	public enum Kind: Hashable, Sendable, CaseIterable {
		/// The Sun's apparent longitude is 0°, near March 20.
		case marchEquinox
		/// The Sun's apparent longitude is 90°, near June 21.
		case juneSolstice
		/// The Sun's apparent longitude is 180°, near September 23.
		case septemberEquinox
		/// The Sun's apparent longitude is 270°, near December 21.
		case decemberSolstice

		/// The Sun's apparent ecliptic longitude at the event.
		public var longitude: Angle {
			.degrees(Double(index) * 90)
		}

		/// The event's index, from 0 for the March equinox.
		var index: Int {
			switch self {
			case .marchEquinox: 0
			case .juneSolstice: 1
			case .septemberEquinox: 2
			case .decemberSolstice: 3
			}
		}
	}

	/// The kind of event.
	public let kind: Kind
	/// The instant of the event.
	public let instant: Instant<TT>

	/// Creates an event.
	init(kind: Kind, instant: Instant<TT>) {
		self.kind = kind
		self.instant = instant
	}
}
