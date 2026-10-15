//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension LeapSecondTable {
	/// A reason a leap second table cannot be used for conversions.
	public enum ValidationError: Error, Hashable, Sendable {
		/// The table has no entries.
		case noEntries
		/// The entry at `index` has an offset or rate that is NaN or infinite.
		case nonFiniteValue(index: Int)
		/// The entry at `index` does not take effect after the entry before it.
		case notInIncreasingOrder(index: Int)
		/// TAI - UTC leaves the right-open interval [0, 86,400) s while the entry at `index`
		/// is in effect.
		case offsetOutOfRange(index: Int)
		/// The last entry has a nonzero rate, so TAI - UTC would drift without bound after it.
		case lastEntryDrifts
		/// The horizon is not after the day the last entry takes effect.
		case horizonNotAfterLastEntry
	}

	/// Checks that the table can be used for UTC conversions.
	///
	/// A valid table has at least one entry, entries in strictly increasing order of
	/// effective day with finite offsets and rates, a constant TAI - UTC after the last entry,
	/// and a horizon after the last entry. TAI - UTC must stay in the right-open interval
	/// [0, 86,400) s, because converting TAI to UTC assumes UTC is behind TAI by less than a
	/// day.
	///
	/// - Throws: A ``ValidationError`` describing the first problem found.
	static func validate(entries: [Entry], horizon: JulianDayNumber) throws(ValidationError) {
		guard let last = entries.last else { throw .noEntries }

		for (index, entry) in entries.enumerated() {
			guard entry.offset.isFinite, entry.rate.isFinite else { throw .nonFiniteValue(index: index) }
			if index > entries.startIndex, entry.effective <= entries[index - 1].effective {
				throw .notInIncreasingOrder(index: index)
			}
		}

		guard last.rate == 0 else { throw .lastEntryDrifts }
		guard horizon > last.effective else { throw .horizonNotAfterLastEntry }

		// TAI - UTC is linear while an entry is in effect, so it stays in range if it is in
		// range at both ends: the entry's effective day and the start of the next entry.
		for (index, entry) in entries.enumerated() {
			let end = index + 1 < entries.count ? entries[index + 1].effective : entry.effective
			for day in [entry.effective, end] {
				let offset = entry.taiMinusUTC(atStartOfUTCDay: day)
				// Also rejects a product that overflows to infinity.
				guard offset >= 0, offset < secondsPerDay else { throw .offsetOutOfRange(index: index) }
			}
		}
	}
}
