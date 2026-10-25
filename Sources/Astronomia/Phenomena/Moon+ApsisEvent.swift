//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// A perigee or apogee of the Moon: an instant when the Moon's geocentric distance is least or
	/// greatest in its orbit.
	///
	/// ```swift
	/// let events = try Moon.apsides(from: start, to: end)
	/// for event in events where event.kind == .perigee {
	/// 	print(event.instant, event.distance.kilometers)
	/// }
	/// ```
	public struct ApsisEvent: Hashable, Sendable {
		/// An apsis.
		public enum Kind: Hashable, Sendable, CaseIterable {
			/// Perigee: the Moon is nearest the Earth, a minimum of the distance.
			case perigee
			/// Apogee: the Moon is farthest from the Earth, a maximum of the distance.
			case apogee
		}

		/// The apsis.
		public let kind: Kind
		/// The instant of the apsis.
		public let instant: Instant<TT>
		/// The geometric distance from the center of the Earth to the center of the Moon at the
		/// instant.
		///
		/// Perigees range from about 356,400 km to 370,400 km, and apogees from about 404,000 km to
		/// 406,700 km.
		public let distance: Distance

		/// Creates an event.
		init(kind: Kind, instant: Instant<TT>, distance: Distance) {
			self.kind = kind
			self.instant = instant
			self.distance = distance
		}
	}
}
