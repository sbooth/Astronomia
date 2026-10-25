//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// A principal phase of the Moon: an instant when the Moon's apparent geocentric ecliptic
	/// longitude exceeds the Sun's by a multiple of 90°.
	///
	/// ```swift
	/// for event in try Moon.phases(from: start, to: end) where event.kind == .fullMoon {
	/// 	print(event.instant)
	/// }
	/// ```
	public struct PhaseEvent: Hashable, Sendable {
		/// A principal phase.
		public enum Kind: Hashable, Sendable, CaseIterable {
			/// New Moon: the Moon's longitude is the Sun's.
			case newMoon
			/// First quarter: the Moon's longitude exceeds the Sun's by 90°.
			case firstQuarter
			/// Full Moon: the Moon's longitude exceeds the Sun's by 180°.
			case fullMoon
			/// Last quarter: the Moon's longitude exceeds the Sun's by 270°.
			case lastQuarter

			/// The excess of the Moon's apparent ecliptic longitude over the Sun's at the phase, by
			/// which the Astronomical Almanac defines the phases: 0°, 90°, 180°, or 270°.
			///
			/// It isn't the Moon's elongation, its angle from the Sun on the sky, which
			/// ``Illumination/elongation`` gives.
			public var excessEclipticLongitude: Angle {
				.degrees(Double(index) * 90)
			}

			/// The phase's index, from 0 for new Moon.
			var index: Int {
				switch self {
				case .newMoon: 0
				case .firstQuarter: 1
				case .fullMoon: 2
				case .lastQuarter: 3
				}
			}
		}

		/// The phase.
		public let kind: Kind
		/// The instant of the phase.
		public let instant: Instant<TT>

		/// Creates an event.
		init(kind: Kind, instant: Instant<TT>) {
			self.kind = kind
			self.instant = instant
		}
	}
}
