//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The eclipses of the Sun.
///
/// The eclipses of the Sun by the Moon have a search of an interval,
/// ``eclipses(from:to:context:earthOrientation:precision:radii:)``, and a search for the next
/// after an instant, `nextEclipse(after:)`, with the built-in ephemeris by default or with one
/// given. Each finds an ``Eclipse``: its kind, its greatest eclipse, gamma, and magnitude, the
/// instants when the Moon's shadow touches the Earth, and where the eclipse is greatest, with
/// the path's width and the central duration there. How an eclipse is seen from a site is a
/// ``LocalEclipse``, from ``Observer``'s `localCircumstances(of:)`, and the eclipses visible from
/// a site are from its `visibleSolarEclipses(from:to:)`.
///
/// ```swift
/// for eclipse in try Sun.eclipses(from: start, to: end) where eclipse.kind == .total {
/// 	print(eclipse.greatestEclipse, eclipse.magnitude)
/// }
/// let next = try Sun.nextEclipse(after: instant)
/// ```
public enum Sun {}
