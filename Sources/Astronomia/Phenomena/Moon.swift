//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Moon's phases, eclipses, and the extremes and crossings of its orbit.
///
/// Each kind of event has a search of an interval and a search for the next after an instant,
/// with the built-in ephemeris by default or with one given:
///
/// - The principal phases: ``phases(from:to:context:earthOrientation:precision:)`` and
///   `nextPhase(_:after:)`, with ``PhaseEvent``. The phase at any instant, as "Waxing Gibbous", is
///   ``PhaseName``, and how the Moon is lit,
///   ``illumination(at:context:observer:earthOrientation:precision:)``.
/// - The eclipses of the Moon:
///   ``eclipses(from:to:context:earthOrientation:precision:shadowModel:)`` and
///   `nextEclipse(after:)`, with ``Eclipse``, and an eclipse seen from a site, ``LocalEclipse``.
/// - The greatest northern and southern declinations:
///   ``greatestDeclinations(from:to:context:earthOrientation:precision:)`` and
///   `nextGreatestDeclination(_:after:)`, with ``GreatestDeclinationEvent``.
/// - Perigee and apogee: ``apsides(from:to:context:precision:)`` and `nextApsis(_:after:)`,
///   with ``ApsisEvent``.
/// - The passages through the ascending and descending nodes:
///   ``nodes(from:to:context:earthOrientation:precision:)`` and `nextNode(_:after:)`, with
///   ``NodeEvent``.
///
/// ```swift
/// let full = try Moon.nextPhase(.fullMoon, after: instant)
/// let perigees = try Moon.apsides(from: start, to: end).filter { $0.kind == .perigee }
/// ```
public enum Moon {}
