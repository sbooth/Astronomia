//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Sun {
	/// An eclipse of the Sun by the Moon, anywhere on the Earth.
	///
	/// The Moon casts a shadow of two cones along the axis through the Moon and the Sun: the
	/// penumbra, within which the Moon hides part of the Sun, and the umbra, within which it hides
	/// all of it, which narrows to a vertex near the Earth and widens beyond it as the antumbra,
	/// within which the Moon is seen within the Sun. An eclipse is partial where only the
	/// penumbra falls on the Earth, total where the umbra does, annular where the antumbra does,
	/// and hybrid where the vertex crosses the Earth's surface, so the eclipse is total along part
	/// of its path and annular along the rest.
	///
	/// The eclipse is greatest when the axis passes nearest the center of the Earth. Its contacts
	/// are the instants when the edge of the penumbra, or of the umbra or the antumbra, first and
	/// last touches the Earth, and when the axis first and last meets it.
	///
	/// The geometry is that of the Besselian elements: the shadow on the fundamental plane,
	/// through the Earth's center perpendicular to the axis, from the Sun's and the Moon's
	/// apparent places seen from the Earth's center, with the Earth as the WGS84 ellipsoid.
	///
	/// ```swift
	/// for eclipse in try Sun.eclipses(from: start, to: end) where eclipse.kind == .total {
	/// 	print(eclipse.greatestEclipse, eclipse.umbralPhase!)
	/// }
	/// ```
	public struct Eclipse: Hashable, Sendable {
		/// Which part of the Moon's shadow falls on the Earth.
		public enum Kind: Hashable, Sendable, CaseIterable {
			/// Only the penumbra falls on the Earth.
			case partial
			/// The antumbra falls on the Earth, where the Moon is seen within the Sun.
			case annular
			/// The umbra falls on the Earth, where the Moon hides all of the Sun.
			case total
			/// The vertex of the umbra crosses the Earth's surface along the central line, so the
			/// eclipse is total along part of it and annular along the rest.
			case hybrid
		}

		/// The radii of the Moon and the Sun that make the Moon's shadow.
		///
		/// The Moon's radius is a ratio to the Earth's equatorial radius, `k`, and differs for the
		/// penumbra and the umbra: the edge of the penumbra is where the Moon's mean limb first
		/// covers the Sun's, and the edge of the umbra where the valleys of its limb, its least
		/// radius, last let the Sun's light through. The Sun's radius is its semidiameter seen
		/// from 1 au. The defaults, ``nasa``, are those of NASA's eclipse predictions.
		public struct Radii: Hashable, Sendable {
			/// The Moon's radius for the penumbra, in equatorial radii of the Earth.
			public let penumbralMoon: Double
			/// The Moon's radius for the umbra and the antumbra, in equatorial radii of the
			/// Earth.
			public let umbralMoon: Double
			/// The Sun's semidiameter seen from 1 au.
			public let sun: Angle

			/// NASA's radii: the Moon's 0.2724880 for the penumbra and 0.2722810 for the umbra,
			/// and the Sun's 959.63" at 1 au, those of Espenak's predictions, including the Five
			/// Millennium Canon of Solar Eclipses.
			public static let nasa = Radii(uncheckedPenumbralMoon: 0.272_488_0, umbralMoon: 0.272_281_0, sun: Angle(arcseconds: 959.63))

			/// Creates radii from values already validated.
			init(uncheckedPenumbralMoon penumbralMoon: Double, umbralMoon: Double, sun: Angle) {
				self.penumbralMoon = penumbralMoon
				self.umbralMoon = umbralMoon
				self.sun = sun
			}

			/// Creates radii of the Moon and the Sun.
			///
			/// - Parameters:
			///   - penumbralMoon: The Moon's radius for the penumbra, in equatorial radii of the
			///     Earth.
			///   - umbralMoon: The Moon's radius for the umbra and the antumbra, in equatorial
			///     radii of the Earth.
			///   - sun: The Sun's semidiameter seen from 1 au.
			/// - Throws:
			///   - ``Sun/EclipseRadiiError/nonFiniteValue`` if a radius is NaN or infinite.
			///   - ``Sun/EclipseRadiiError/nonPositiveValue`` if a radius isn't positive.
			public init(penumbralMoon: Double, umbralMoon: Double, sun: Angle) throws(Sun.EclipseRadiiError) {
				for value in [penumbralMoon, umbralMoon, sun.radians] {
					guard value.isFinite else { throw .nonFiniteValue }
					guard value > 0 else { throw .nonPositiveValue }
				}
				self.init(uncheckedPenumbralMoon: penumbralMoon, umbralMoon: umbralMoon, sun: sun)
			}
		}

		/// Where an eclipse is greatest at greatest eclipse, and its circumstances there.
		///
		/// For a central eclipse, the place is where the axis of the shadow meets the Earth; for
		/// one that isn't, the point of the Earth's limb nearest the axis, where the Sun is on the
		/// horizon. The place is on the WGS84 ellipsoid, turned with the Earth by the UT1 of the
		/// ``EarthOrientation``, so its longitude depends on ΔT, by about 0.004° a second.
		public struct Site: Hashable, Sendable {
			/// The geodetic latitude.
			public let latitude: Angle
			/// The longitude, positive east, in the closed interval [-180, 180]°.
			public let longitude: Angle
			/// The altitude of the Sun, without refraction.
			public let sunAltitude: Angle
			/// The azimuth of the Sun, from the north through the east, in the right-open interval
			/// [0, 360)°.
			public let sunAzimuth: Angle
			/// The width of the path of the umbra or the antumbra across the place, on the plane
			/// tangent to the Earth there, as eclipse catalogs give it, or `nil` for an eclipse
			/// that isn't central, or whose umbra or antumbra isn't wholly on the Earth at greatest
			/// eclipse, so its path has only one limit there.
			public let pathWidth: Distance?
			/// From when the umbra or the antumbra reaches the place to when it leaves it: the
			/// central duration at greatest eclipse, or `nil` for an eclipse that isn't central.
			public let centralPhase: ClosedRange<Instant<TT>>?
		}

		/// Which part of the Moon's shadow falls on the Earth.
		public let kind: Kind
		/// Whether the axis of the shadow meets the Earth, so the eclipse has a central line;
		/// otherwise, for an annular or total eclipse, only the edge of the antumbra or the umbra
		/// does.
		public let isCentral: Bool
		/// The instant when the axis of the shadow passes nearest the Earth's center.
		public let greatestEclipse: Instant<TT>
		/// The least distance of the axis of the shadow from the Earth's center, in equatorial
		/// radii of the Earth, positive when the axis passes north of the center.
		public let gamma: Double
		/// The magnitude at greatest eclipse, where the eclipse is greatest on the Earth.
		///
		/// For a central eclipse, the ratio of the Moon's apparent diameter to the Sun's where
		/// the axis meets the Earth. For an eclipse that isn't central, the fraction of the Sun's
		/// diameter the Moon covers at the Earth's limb nearest the axis, which for a total
		/// eclipse, within the umbra, exceeds 1, as NASA's catalogs give it.
		public let magnitude: Double
		/// Where the eclipse is greatest at greatest eclipse, and its circumstances there.
		public let greatestEclipseSite: Site
		/// From when the penumbra first touches the Earth (P1) to when it last does (P4).
		public let partialPhase: ClosedRange<Instant<TT>>
		/// From when the umbra or the antumbra first touches the Earth (U1) to when it last does
		/// (U4), or `nil` for a partial eclipse.
		public let umbralPhase: ClosedRange<Instant<TT>>?
		/// From when the axis of the shadow first meets the Earth (C1) to when it last does (C2),
		/// the span of the central line, or `nil` for an eclipse that isn't central.
		public let centralPhase: ClosedRange<Instant<TT>>?
		/// The radii of the Moon and the Sun.
		public let radii: Radii
	}
}
