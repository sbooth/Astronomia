//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Moon {
	/// An eclipse of the Moon by the Earth's shadow, seen from the center of the Earth.
	///
	/// The Moon passes through the penumbra, where the Earth hides part of the Sun, and may pass
	/// into the umbra, where the Earth hides all of it. The eclipse is greatest when the Moon's
	/// center is nearest the axis of the shadow, the direction opposite the Sun. Its contacts are
	/// the instants when the Moon's limb touches the edge of the penumbra or the umbra.
	///
	/// The shadow's radii, as seen from the Earth's center, are made from the Moon's and the Sun's
	/// horizontal parallaxes and the Sun's semidiameter, enlarged for the Earth's atmosphere by a
	/// ``ShadowModel``.
	///
	/// ```swift
	/// for eclipse in try Moon.eclipses(from: start, to: end) where eclipse.kind == .total {
	/// 	print(eclipse.greatestEclipse, eclipse.totalPhase!)
	/// }
	/// ```
	public struct Eclipse: Hashable, Sendable {
		/// How deeply the Moon enters the Earth's shadow.
		public enum Kind: Hashable, Sendable, CaseIterable {
			/// The Moon enters the penumbra but not the umbra.
			case penumbral
			/// The Moon enters the umbra, but not wholly.
			case partial
			/// The Moon is wholly within the umbra.
			case total
		}

		/// How the Earth's atmosphere enlarges its shadow.
		///
		/// With the Moon's equatorial horizontal parallax π_M, the Sun's π_S, and the Sun's
		/// semidiameter s_S, the radii of the penumbra and the umbra are:
		///
		/// | Model | Penumbra | Umbra |
		/// | --- | --- | --- |
		/// | ``danjon`` | 1.01 π_M + π_S + s_S | 1.01 π_M + π_S - s_S |
		/// | ``chauvenet`` | 1.02 (0.99834 π_M + π_S + s_S) | 1.02 (0.99834 π_M + π_S - s_S) |
		///
		/// Danjon's method gives umbral magnitudes about 0.006 smaller than Chauvenet's, and
		/// penumbral magnitudes about 0.026 smaller.
		public enum ShadowModel: Hashable, Sendable, CaseIterable {
			/// Danjon's method, which enlarges the Earth's radius by 1/85 for the atmosphere and
			/// reduces it by 1/594 for the Earth's flattening at latitude 45°, about 1%, as the
			/// Connaissance des Temps has since 1951, and as Meeus, NASA's Five Millennium Canon of
			/// Lunar Eclipses, and Skyfield do.
			case danjon
			/// Chauvenet's method, which enlarges the radii of the shadow by 1/50, after reducing
			/// the Earth's radius for its flattening at latitude 45°, the traditional convention
			/// since Chauvenet (1891) of many national almanacs.
			case chauvenet
		}

		/// How deeply the Moon enters the Earth's shadow.
		public let kind: Kind
		/// The instant when the Moon's center is nearest the axis of the shadow.
		public let greatestEclipse: Instant<TT>
		/// The fraction of the Moon's diameter within the umbra at greatest eclipse, negative for a
		/// penumbral eclipse, for which it is the fraction by which the Moon misses the umbra.
		public let umbralMagnitude: Double
		/// The fraction of the Moon's diameter within the penumbra at greatest eclipse.
		public let penumbralMagnitude: Double
		/// The least distance of the Moon's center from the axis of the shadow, in equatorial radii
		/// of the Earth, in the plane through the Moon perpendicular to the axis, positive when the
		/// Moon passes north of the axis in the true equator of date.
		public let gamma: Double
		/// From the first contact with the penumbra (P1) to the last (P4).
		public let penumbralPhase: ClosedRange<Instant<TT>>
		/// From the first contact with the umbra (U1) to the last (U4), or `nil` for a penumbral
		/// eclipse.
		public let partialPhase: ClosedRange<Instant<TT>>?
		/// From the instant the Moon is wholly within the umbra (U2) to the instant it begins to
		/// leave it (U3), or `nil` for a partial or penumbral eclipse.
		public let totalPhase: ClosedRange<Instant<TT>>?
		/// The angular distance of the Moon's center from the axis of the shadow at greatest
		/// eclipse.
		public let separation: Angle
		/// The angular radius of the penumbra at greatest eclipse.
		public let penumbraRadius: Angle
		/// The angular radius of the umbra at greatest eclipse.
		public let umbraRadius: Angle
		/// The Moon's angular radius at greatest eclipse.
		public let moonRadius: Angle
		/// The model of the shadow.
		public let shadowModel: ShadowModel
	}
}
