//
// SPDX-FileCopyrightText: 2023 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation

extension FloatingPoint {
	/// Returns the value of `self` multiplied by `π/180`.
	public func degreesToRadians() -> Self {
		self * .pi / 180
	}

	/// Returns the value of `self` multiplied by `180/π`.
	public func radiansToDegrees() -> Self {
		self * 180 / .pi
	}

	/// Returns the value of `self` multiplied by `360/24`.
	public func hoursToDegrees() -> Self {
		self * 15
	}

	/// Returns the value of `self` multiplied by `24/360`.
	public func degreesToHours() -> Self {
		self / 15
	}

	/// Returns the value of `self` multiplied by `2π/24`.
	public func hoursToRadians() -> Self {
		self * .pi / 12
	}

	/// Returns the value of `self` multiplied by `24/2π`.
	public func radiansToHours() -> Self {
		self * 12 / .pi
	}
}

extension FloatingPoint {
	/// Returns the value of `self` mapped to the interval `[0, 360)`.
	public func normalizedDegrees() -> Self {
		let result = self.truncatingRemainder(dividingBy: 360)
		return result < 0 ? result + 360 : result
	}

	/// Returns the value of `self` mapped to the interval `[0, 24)`.
	public func normalizedHours() -> Self {
		let result = self.truncatingRemainder(dividingBy: 24)
		return result < 0 ? result + 24 : result
	}

	/// Returns the value of `self` mapped to the interval `[0, 2π)`.
	public func normalizedRadians() -> Self {
		let twoPi = 2 * Self.pi
		let result = self.truncatingRemainder(dividingBy: twoPi)
		return result < 0 ? result + twoPi : result
	}
}
