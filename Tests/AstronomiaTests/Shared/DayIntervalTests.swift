//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import Testing
@testable import Astronomia

/// An unvalidated day interval payload with the same coding keys as `DayInterval`.
private struct RawDayInterval: Encodable {
	let days: Int
	let fractionalDay: Double
}

@Suite struct DayIntervalTests {
	// MARK: - Creation

	@Test func zero() {
		#expect(DayInterval.zero.days == 0)
		#expect(DayInterval.zero.fractionalDay == 0)
		#expect(DayInterval.zero.inDays == 0)
		#expect(DayInterval.zero.inSeconds == 0)
	}

	@Test func initFromDaysAndFraction() throws {
		let interval = try DayInterval(days: 2, fractionalDay: 0.25)
		#expect(interval.days == 2)
		#expect(interval.fractionalDay == 0.25)
		#expect(try DayInterval(days: 3) == DayInterval(days: 3, fractionalDay: 0))
	}

	@Test func fractionalDayIsNormalized() throws {
		// days is the nearest whole number of days with halves rounded up, and the fraction is in [-0.5, 0.5)
		#expect(try DayInterval(days: 1, fractionalDay: 0.75) == DayInterval(days: 2, fractionalDay: -0.25))
		#expect(try DayInterval(days: 0, fractionalDay: -0.75) == DayInterval(days: -1, fractionalDay: 0.25))
		#expect(try DayInterval(days: 0, fractionalDay: 10.25) == DayInterval(days: 10, fractionalDay: 0.25))

		let half = try DayInterval(days: 0, fractionalDay: 0.5)
		#expect(half.days == 1)
		#expect(half.fractionalDay == -0.5)
		let negativeHalf = try DayInterval(days: 0, fractionalDay: -0.5)
		#expect(negativeHalf.days == 0)
		#expect(negativeHalf.fractionalDay == -0.5)

		let negativeZero = try DayInterval(days: 1, fractionalDay: -0.0)
		#expect(negativeZero.fractionalDay.sign == .plus)
		#expect(negativeZero == (try DayInterval(days: 1)))
	}

	@Test func initFromDaysAndFractionErrors() throws {
		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(days: 0, fractionalDay: .nan) }
		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(days: 0, fractionalDay: .infinity) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max, fractionalDay: 0.5) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .min, fractionalDay: -0.75) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: 0, fractionalDay: 1e300) }
		#expect(try DayInterval(days: .max, fractionalDay: 0.25).days == .max)
		#expect(try DayInterval(days: .min, fractionalDay: -0.5).days == .min)
	}

	@Test func initFromDoubleDays() throws {
		#expect(try DayInterval(days: 0.75) == DayInterval(days: 1, fractionalDay: -0.25))
		#expect(try DayInterval(days: -2.5) == DayInterval(days: -2, fractionalDay: -0.5))
		#expect(try DayInterval(days: 2.5) == DayInterval(days: 3, fractionalDay: -0.5))
		#expect(try DayInterval(days: -0x1p63).days == .min)
		#expect(try DayInterval(days1: 1e16, days2: 0.25) == DayInterval(days: 10_000_000_000_000_000, fractionalDay: 0.25))
		#expect(try DayInterval(days1: 0.375, days2: 0.375) == DayInterval(days: 1, fractionalDay: -0.25))

		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(days: .nan) }
		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(days1: 0, days2: -.infinity) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: 0x1p63) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: 1e300) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days1: .greatestFiniteMagnitude, days2: .greatestFiniteMagnitude) }
	}

	@Test func initFromSeconds() throws {
		#expect(try DayInterval(seconds: 86_400) == DayInterval(days: 1))
		#expect(try DayInterval(seconds: 43_200) == DayInterval(days: 1, fractionalDay: -0.5))
		#expect(try DayInterval(seconds: -43_200) == DayInterval(days: 0, fractionalDay: -0.5))
		#expect(try DayInterval(seconds: 21_600) == DayInterval(days: 0, fractionalDay: 0.25))
		#expect(try DayInterval(seconds: -129_600) == DayInterval(days: -1, fractionalDay: -0.5))
		#expect(try DayInterval(seconds: 1).fractionalDay == 1.0 / 86_400)
		#expect(try DayInterval(seconds1: 86_400e6, seconds2: 0.5) == DayInterval(days: 1_000_000, fractionalDay: 0.5 / 86_400))

		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(seconds: .nan) }
		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval(seconds1: 1, seconds2: .infinity) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(seconds: 1e300) }
	}

	// MARK: - Conversions

	@Test func inDaysAndSeconds() throws {
		let interval = try DayInterval(days: 2, fractionalDay: -0.25)
		#expect(interval.inDays == 1.75)
		#expect(interval.inSeconds == 151_200)
		#expect(try DayInterval(days: -3, fractionalDay: 0.5).inDays == -2.5)
		#expect(try DayInterval(days: -3, fractionalDay: 0.5).inSeconds == -216_000)
		#expect(try DayInterval(seconds: 1).inSeconds == 1)
	}

	@Test func wholeAndFractionalSeconds() throws {
		#expect(try DayInterval(days: 0.5).wholeAndFractionalSeconds == (43_200, 0))
		#expect(try DayInterval(seconds: 1.25).wholeAndFractionalSeconds == (1, 0.25))
		#expect(try DayInterval(seconds: -1.75).wholeAndFractionalSeconds == (-2, 0.25))
		// Halves round up so the fractional second stays in [-0.5, 0.5)
		#expect(try DayInterval(seconds1: 86_400e6, seconds2: 0.5).wholeAndFractionalSeconds == (86_400_000_001, -0.5))
		// Whole seconds beyond Int fall back to a rounded Double
		#expect(try DayInterval(days: .max).wholeAndFractionalSeconds == (Double(Int.max) * 86_400, 0))
		#expect(try DayInterval(days: .min).wholeAndFractionalSeconds == (Double(Int.min) * 86_400, 0))
	}

	// MARK: - Arithmetic

	@Test func addingAndSubtractingIntervals() throws {
		let a = try DayInterval(days: 1, fractionalDay: 0.25)
		let b = try DayInterval(days: 2, fractionalDay: -0.5)
		#expect(try a.adding(b) == DayInterval(days: 3, fractionalDay: -0.25))
		#expect(try a.subtracting(b) == DayInterval(days: 0, fractionalDay: -0.25))
		#expect(try b.subtracting(a) == DayInterval(days: 0, fractionalDay: 0.25))
		#expect(try a.adding(.zero) == a)
		#expect(try a.subtracting(a) == .zero)

		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max).adding(DayInterval(days: 1)) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .min).subtracting(DayInterval(days: 1)) }
	}

	@Test func addingDays() throws {
		let interval = try DayInterval(days: 1, fractionalDay: 0.25)
		#expect(try interval.adding(days: 2) == DayInterval(days: 3, fractionalDay: 0.25))
		#expect(try interval.adding(days: -1) == DayInterval(days: 0, fractionalDay: 0.25))
		#expect(try interval.adding(days: 0.5) == DayInterval(days: 2, fractionalDay: -0.25))
		#expect(try interval.adding(days: -1.25) == .zero)
		// Only the result has to be representable
		#expect(try DayInterval(days: .max).adding(days: -0x1p63) == DayInterval(days: -1))

		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max).adding(days: 1) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .min).adding(days: -1) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max, fractionalDay: 0.25).adding(days: 0.25) }
		#expect(throws: DayIntervalError.nonFiniteValue) { try interval.adding(days: .nan) }
	}

	@Test func addingSeconds() throws {
		#expect(try DayInterval(days: 1).adding(seconds: 43_200) == DayInterval(days: 2, fractionalDay: -0.5))
		#expect(try DayInterval(days: 1).adding(seconds: -21_600) == DayInterval(days: 1, fractionalDay: -0.25))
		#expect(try DayInterval(days: -1).adding(seconds: 86_400) == .zero)
		#expect(throws: DayIntervalError.nonFiniteValue) { try DayInterval.zero.adding(seconds: .infinity) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max).adding(seconds: 86_400) }
	}

	@Test func negated() throws {
		#expect(try DayInterval(days: 2, fractionalDay: 0.25).negated() == DayInterval(days: -2, fractionalDay: -0.25))
		#expect(try DayInterval(days: -2, fractionalDay: -0.25).negated() == DayInterval(days: 2, fractionalDay: 0.25))
		// -(2 - 0.5) is -1 - 0.5, keeping the fraction in [-0.5, 0.5)
		#expect(try DayInterval(days: 2, fractionalDay: -0.5).negated() == DayInterval(days: -1, fractionalDay: -0.5))
		#expect(try DayInterval(days: 0, fractionalDay: -0.5).negated() == DayInterval(days: 1, fractionalDay: -0.5))
		let zero = try DayInterval.zero.negated()
		#expect(zero == .zero)
		#expect(zero.fractionalDay.sign == .plus)
		#expect(try DayInterval(days: .max).negated().days == -Int.max)
		#expect(try DayInterval(days: .max, fractionalDay: -0.5).negated().days == Int.min + 2)

		for (days, fraction) in [(0, 0.25), (3, -0.5), (-7, 0.375), (1_000_000, -0.125)] {
			let interval = try DayInterval(days: days, fractionalDay: fraction)
			#expect(try interval.negated().inDays == -interval.inDays)
			#expect(try interval.negated().negated() == interval)
			#expect(try interval.adding(interval.negated()) == .zero)
		}

		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .min).negated() }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .min + 1, fractionalDay: -0.5).negated() }
	}

	@Test func multipliedByInteger() throws {
		let interval = try DayInterval(days: 1, fractionalDay: 0.25)
		#expect(try interval.multiplied(by: 0) == .zero)
		#expect(try interval.multiplied(by: 1) == interval)
		#expect(try interval.multiplied(by: -1) == interval.negated())
		#expect(try interval.multiplied(by: 2) == DayInterval(days: 3, fractionalDay: -0.5))
		#expect(try interval.multiplied(by: -3) == DayInterval(days: -4, fractionalDay: 0.25))
		#expect(try interval.multiplied(by: 1_000_000) == DayInterval(days: 1_250_000))

		// Whole days are exact even when the multiplier needs more than 53 bits
		#expect(try DayInterval(days: 1).multiplied(by: .max) == DayInterval(days: .max))
		#expect(try DayInterval(days: -1).multiplied(by: .max) == DayInterval(days: -Int.max))
		#expect(try DayInterval(days: 0, fractionalDay: 0.25).multiplied(by: .max) == DayInterval(days: 2_305_843_009_213_693_952, fractionalDay: -0.25))
		#expect(try DayInterval(days: 0, fractionalDay: -0.5).multiplied(by: .min) == DayInterval(days: 4_611_686_018_427_387_904))

		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: 2).multiplied(by: .max) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: -1).multiplied(by: .min) }
	}

	@Test func multipliedByScalar() throws {
		let interval = try DayInterval(days: 1, fractionalDay: 0.25)
		#expect(try interval.multiplied(by: 0.0) == .zero)
		#expect(try interval.multiplied(by: 1.0) == interval)
		#expect(try interval.multiplied(by: -1.0) == interval.negated())
		#expect(try interval.multiplied(by: 0.5) == DayInterval(days: 1, fractionalDay: -0.375))
		#expect(try interval.multiplied(by: -2.0) == DayInterval(days: -2, fractionalDay: -0.5))
		#expect(try DayInterval(days: 2).multiplied(by: 1.5) == DayInterval(days: 3))
		#expect(try DayInterval(days: 1_000_000_007).multiplied(by: 0.25) == DayInterval(days: 250_000_002, fractionalDay: -0.25))

		#expect(throws: DayIntervalError.nonFiniteValue) { try interval.multiplied(by: .nan) }
		#expect(throws: DayIntervalError.nonFiniteValue) { try interval.multiplied(by: .infinity) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try interval.multiplied(by: 1e300) }
		#expect(throws: DayIntervalError.dayCountNotRepresentable) { try DayInterval(days: .max).multiplied(by: 2.0) }
	}

	// MARK: - Comparison

	@Test func comparison() throws {
		let values = try [
			DayInterval(days: -2),
			DayInterval(days: -1, fractionalDay: -0.5),
			DayInterval(days: -1, fractionalDay: 0.25),
			DayInterval.zero,
			DayInterval(days: 0, fractionalDay: 0.25),
			DayInterval(days: 1, fractionalDay: -0.5),
			DayInterval(days: 1),
		]
		for (i, lhs) in values.enumerated() {
			for (j, rhs) in values.enumerated() {
				#expect((lhs < rhs) == (i < j), "\(lhs) < \(rhs)")
				#expect((lhs < rhs) == (lhs.inDays < rhs.inDays))
			}
		}
		#expect(values.reversed().sorted() == values)
	}

	@Test func equalityAndHashing() throws {
		let a = try DayInterval(days: 1, fractionalDay: 0.75)
		let b = try DayInterval(days: 1.75)
		let c = try DayInterval(seconds: 151_200)
		#expect(a == b)
		#expect(b == c)
		#expect(a.hashValue == c.hashValue)
		#expect(Set([a, b, c, .zero]).count == 2)
	}

	// MARK: - Descriptions

	@Test func descriptions() throws {
		#expect(try DayInterval(days: 1).description == "1 days")
		#expect(DayInterval.zero.description == "0 days")
		#expect(try DayInterval(days: 2, fractionalDay: -0.25).description == "2 - 0.25 days")
		#expect(try DayInterval(days: 0, fractionalDay: 0.25).description == "0 + 0.25 days")
		#expect(try DayInterval(days: -3, fractionalDay: 0.5).description == "-2 - 0.5 days")
		#expect(try DayInterval(days: 2, fractionalDay: -0.25).debugDescription == "DayInterval(days: 2, fractionalDay: -0.25)")
	}

	// MARK: - Coding

	@Test func codableRoundTrip() throws {
		let intervals = try [
			DayInterval.zero,
			DayInterval(days: 2, fractionalDay: -0.25),
			DayInterval(days: .max, fractionalDay: 0.25),
			DayInterval(days: .min, fractionalDay: -0.5),
			DayInterval(seconds: 1),
		]
		for interval in intervals {
			let data = try JSONEncoder().encode(interval)
			#expect(try JSONDecoder().decode(DayInterval.self, from: data) == interval)
		}
	}

	@Test func decodingNormalizesFraction() throws {
		let data = try JSONEncoder().encode(RawDayInterval(days: 0, fractionalDay: 1.25))
		#expect(try JSONDecoder().decode(DayInterval.self, from: data) == DayInterval(days: 1, fractionalDay: 0.25))
	}

	@Test func decodingInvalidValuesThrows() throws {
		let unrepresentable = try JSONEncoder().encode(RawDayInterval(days: .max, fractionalDay: 0.75))
		#expect(throws: DecodingError.self) { try JSONDecoder().decode(DayInterval.self, from: unrepresentable) }

		let encoder = JSONEncoder()
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let decoder = JSONDecoder()
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
		let nonFinite = try encoder.encode(RawDayInterval(days: 1, fractionalDay: -.infinity))
		#expect(throws: DecodingError.self) { try decoder.decode(DayInterval.self, from: nonFinite) }
	}
}
