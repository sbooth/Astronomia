//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The local circumstances of an eclipse of the Moon: where the Moon is in the sky of a site at
/// each contact, and when it is up.
///
/// An eclipse of the Moon is the same for every observer who sees it: its contacts are the
/// instants when the Moon's limb touches the edge of the Earth's shadow, seen from the Earth's
/// center, as NASA's catalogs give them. What a site adds is whether the Moon is above its
/// horizon, and where. The Moon is up when its upper limb is above the altitude of rising and
/// setting, by default the standard -34', as for the Moon's rise and set times from
/// ``Observer``'s `riseTransitSetEvents(of:from:to:)`.
///
/// ```swift
/// let site = try Observer.site(latitude: .degrees(19.8207), longitude: .degrees(-155.4681))
/// let local = try site.localCircumstances(of: eclipse)
/// for circumstance in local.contacts where circumstance.isMoonUp {
/// 	print(circumstance.contact, circumstance.place.altitude.degrees)
/// }
/// ```
public struct LocalLunarEclipse: Hashable, Sendable {
	/// A contact of the Moon with the Earth's shadow, or greatest eclipse.
	public enum Contact: Hashable, Sendable, CaseIterable {
		/// The first contact with the penumbra, P1.
		case penumbralBegins
		/// The first contact with the umbra, U1.
		case partialBegins
		/// The Moon is wholly within the umbra, U2.
		case totalBegins
		/// Greatest eclipse, when the Moon's center is nearest the axis of the shadow.
		case greatestEclipse
		/// The Moon begins to leave the umbra, U3.
		case totalEnds
		/// The last contact with the umbra, U4.
		case partialEnds
		/// The last contact with the penumbra, P4.
		case penumbralEnds
	}

	/// The Moon's place at a contact.
	public struct Circumstance: Hashable, Sendable {
		/// The contact.
		public let contact: Contact
		/// The instant of the contact.
		public let instant: Instant<TT>
		/// The Moon's observed place, refracted if the atmosphere was given.
		public let place: ObservedPlace
		/// Whether the Moon's upper limb is above the altitude of rising and setting.
		public let isMoonUp: Bool
	}

	/// The eclipse.
	public let eclipse: LunarEclipse
	/// The site.
	public let observer: Observer
	/// The Moon's place at each contact of the eclipse, and at greatest eclipse, in order.
	public let contacts: [Circumstance]
	/// The Moon's risings and settings during the eclipse, from the first contact with the
	/// penumbra to the last, in order.
	public let moonrisesAndMoonsets: [RiseTransitSetEvent]
	/// The parts of the eclipse when the Moon is up, in order.
	public let visibleIntervals: [ClosedRange<Instant<TT>>]

	/// Whether the Moon is up at some time during the eclipse.
	public var isVisible: Bool {
		!visibleIntervals.isEmpty
	}

	/// Returns the Moon's place at a contact, or `nil` if the eclipse has no such contact, as
	/// a partial eclipse has no total phase.
	///
	/// - Parameter contact: The contact.
	/// - Returns: The Moon's place at the contact.
	public func circumstance(at contact: Contact) -> Circumstance? {
		contacts.first { $0.contact == contact }
	}

	/// Returns the parts of a phase of the eclipse when the Moon is up, in order.
	///
	/// - Parameter phase: The phase, as ``LunarEclipse/penumbralPhase``,
	///   ``LunarEclipse/partialPhase``, or ``LunarEclipse/totalPhase``.
	/// - Returns: The visible parts of the phase.
	public func visibleIntervals(of phase: ClosedRange<Instant<TT>>) -> [ClosedRange<Instant<TT>>] {
		visibleIntervals.compactMap { interval in
			let lower = max(interval.lowerBound, phase.lowerBound)
			let upper = min(interval.upperBound, phase.upperBound)
			return lower <= upper ? lower ... upper : nil
		}
	}
}
