//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Sun {
	/// The local circumstances of an eclipse of the Sun: how it is seen from a site, when its
	/// contacts are there, where the Sun is in the sky at each, and when the Sun is up.
	///
	/// Unlike an eclipse of the Moon, an eclipse of the Sun differs from place to place: its
	/// contacts are the instants when the Moon's limb touches the Sun's, seen from the site. The
	/// partial eclipse begins (C1) and ends (C4) when the limbs touch outside each other, and an
	/// annular or total eclipse begins (C2) and ends (C3) when they touch inside. The eclipse is
	/// greatest at maximum, when the centers are nearest. The radii of the Moon and the Sun are
	/// those of the ``Eclipse``, NASA's by default: the Moon's mean radius for the partial phase
	/// and its least, of the valleys of its limb, for the total or annular phase.
	///
	/// The Sun is up when its upper limb is above the altitude of rise and set, by default the
	/// standard -34', as for the Sun's rise and set times from ``Observer``'s
	/// `riseTransitSetEvents(of:from:to:)`.
	///
	/// ```swift
	/// let site = try Observer.site(latitude: .degrees(37.0), longitude: .degrees(-89.2))
	/// if let local = try site.localCircumstances(of: eclipse), local.kind == .total {
	/// 	print(local.centralPhase!, local.circumstance(at: .maximum)!.place.altitude.degrees)
	/// }
	/// ```
	public struct LocalEclipse: Hashable, Sendable {
		/// How the eclipse is seen from the site.
		public enum Kind: Hashable, Sendable, CaseIterable {
			/// The Moon covers part of the Sun.
			case partial
			/// The Moon is seen wholly within the Sun.
			case annular
			/// The Moon covers all of the Sun.
			case total
		}

		/// A contact of the Moon's limb with the Sun's, or maximum eclipse.
		public enum Contact: Hashable, Sendable, CaseIterable {
			/// The partial eclipse begins, C1.
			case partialBegins
			/// The annular or total eclipse begins, C2.
			case centralBegins
			/// Maximum eclipse, when the magnitude is greatest.
			case maximum
			/// The annular or total eclipse ends, C3.
			case centralEnds
			/// The partial eclipse ends, C4.
			case partialEnds
		}

		/// The Sun's place at a contact.
		public struct Circumstance: Hashable, Sendable {
			/// The contact.
			public let contact: Contact
			/// The instant of the contact.
			public let instant: Instant<TT>
			/// The Sun's observed place, refracted if the atmosphere was given.
			public let place: ObservedPlace
			/// The position angle of the point of contact on the Sun's limb, or at maximum of the
			/// Moon's center from the Sun's, from the north point of the Sun's disk toward the
			/// east, in the right-open interval [0, 360)°, as NASA's catalogs give it.
			///
			/// The point of contact is toward the Moon's center at C1 and C4, and at C2 and C3 of
			/// an annular eclipse, and away from it at C2 and C3 of a total eclipse, where the
			/// Moon covers the Sun.
			public let positionAngle: Angle
			/// The position angle from the zenith point of the Sun's disk toward the east, in the
			/// right-open interval [0, 360)°: the position angle less the Sun's parallactic angle.
			public let zenithPositionAngle: Angle
			/// Whether the Sun's upper limb is above the altitude of rise and set.
			public let isSunUp: Bool
		}

		/// The eclipse.
		public let eclipse: Sun.Eclipse
		/// The site.
		public let observer: Observer
		/// How the eclipse is seen from the site.
		public let kind: Kind
		/// The magnitude at maximum, as that of the ``Eclipse``: for a partial eclipse, the
		/// fraction of the Sun's diameter the Moon covers, and for an annular or total eclipse,
		/// the ratio of the Moon's apparent diameter to the Sun's.
		public let magnitude: Double
		/// The fraction of the Sun's area the Moon covers at maximum, with the Moon's radius for
		/// the total or annular phase, as NASA's catalogs give it.
		public let obscuration: Double
		/// The greatest magnitude while the Sun is up: at maximum, if the Sun is up then, or else
		/// at the sunrise or sunset nearest it, as NASA's tables give it for an eclipse in
		/// progress at sunrise or sunset; or `nil` if the Sun isn't up during the eclipse.
		public let visibleMagnitude: Double?
		/// The obscuration when the magnitude while the Sun is up is greatest, or `nil` if the
		/// Sun isn't up during the eclipse.
		public let visibleObscuration: Double?
		/// From when the partial eclipse begins (C1) to when it ends (C4).
		public let partialPhase: ClosedRange<Instant<TT>>
		/// From when the annular or total eclipse begins (C2) to when it ends (C3), or `nil` for a
		/// partial eclipse.
		public let centralPhase: ClosedRange<Instant<TT>>?
		/// The Sun's place at each contact, and at maximum, in order.
		public let contacts: [Circumstance]
		/// The Sun's rises and sets during the partial phase, in order.
		public let sunrisesAndSunsets: [RiseTransitSetEvent]
		/// The parts of the partial phase when the Sun is up, in order.
		public let visibleIntervals: [ClosedRange<Instant<TT>>]

		/// Whether the Sun is up at some time during the eclipse.
		public var isVisible: Bool {
			!visibleIntervals.isEmpty
		}

		/// Returns the Sun's place at a contact, or `nil` if the eclipse has no such contact at the
		/// site, as a partial eclipse has no central phase.
		///
		/// - Parameter contact: The contact.
		/// - Returns: The Sun's place at the contact.
		public func circumstance(at contact: Contact) -> Circumstance? {
			contacts.first { $0.contact == contact }
		}

		/// Returns the parts of a phase of the eclipse when the Sun is up, in order.
		///
		/// - Parameter phase: The phase, as ``partialPhase`` or ``centralPhase``.
		/// - Returns: The visible parts of the phase.
		public func visibleIntervals(of phase: ClosedRange<Instant<TT>>) -> [ClosedRange<Instant<TT>>] {
			visibleIntervals.compactMap { interval in
				let lower = max(interval.lowerBound, phase.lowerBound)
				let upper = min(interval.upperBound, phase.upperBound)
				return lower <= upper ? lower ... upper : nil
			}
		}
	}
}
