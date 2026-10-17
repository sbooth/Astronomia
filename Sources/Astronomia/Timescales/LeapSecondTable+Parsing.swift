//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension LeapSecondTable {
	/// Creates a table from the contents of the IERS/IETF `leap-seconds.list`.
	///
	/// Each data line holds the NTP seconds since 1900-01-01 at the start of a UTC day and
	/// TAI - UTC from then on. The `#@` line holds the file's expiry, which becomes the
	/// horizon: the UTC day of the expiry, the first not covered by the file.
	///
	/// - Note: The file's `#h` hash is not checked. `Scripts/generate-timescale-data.py
	///   leap-seconds` checks it when generating leap seconds to compile in.
	/// - Parameter text: The contents of the file.
	/// - Returns: `nil` if the expiry is missing, a data line is malformed or not at the start
	///   of a UTC day, or the leap seconds fail the checks of ``init(leapSeconds:horizon:)``.
	/// - SeeAlso: [leap-seconds.list](https://hpiers.obspm.fr/iers/bul/bulc/ntp/leap-seconds.list)
	public init?(leapSecondsList text: String) {
		/// The civil Julian day number of a whole number of NTP days, from 1900-01-01.
		func day(ntpDays: Int) -> JulianDayNumber? {
			let (day, overflow) = 2_415_021.addingReportingOverflow(ntpDays)
			return overflow ? nil : day
		}

		var expiry: JulianDayNumber?
		var leapSeconds: [LeapSecond] = []
		for line in text.split(whereSeparator: \.isNewline) {
			if line.hasPrefix("#@") {
				// #@	4023129600
				guard let field = line.dropFirst(2).split(whereSeparator: \.isWhitespace).first,
					  let seconds = Int(field), seconds >= 0, let day = day(ntpDays: seconds / 86_400)
				else { return nil }
				expiry = day
				continue
			}
			// Other comments, including #$ and #h
			let data = line.prefix { $0 != "#" }
			let fields = data.split(whereSeparator: \.isWhitespace)
			if fields.isEmpty { continue }
			guard fields.count == 2, let seconds = Int(fields[0]), let offset = Int(fields[1]), seconds >= 0 else {
				return nil
			}
			let (days, remainder) = seconds.quotientAndRemainder(dividingBy: 86_400)
			guard remainder == 0, let day = day(ntpDays: days) else { return nil }
			leapSeconds.append(LeapSecond(effective: day, taiMinusUTC: offset))
		}

		guard let expiry else { return nil }
		self.init(leapSeconds: leapSeconds, horizon: expiry)
	}

	/// Creates a table from the contents of the IERS `Leap_Second.dat`.
	///
	/// Each data line holds the MJD, day, month, and year of the start of a UTC day and
	/// TAI - UTC from then on. The comment `File expires on 28 June 2027` gives the expiry,
	/// which becomes the horizon: the UTC day of the expiry, the first not covered by the file.
	///
	/// - Parameter text: The contents of the file.
	/// - Returns: `nil` if the expiry is missing or malformed, a data line is malformed or its
	///   MJD does not match its date, or the leap seconds fail the checks of
	///   ``init(leapSeconds:horizon:)``.
	/// - SeeAlso: [Leap_Second.dat](https://hpiers.obspm.fr/iers/bul/bulc/Leap_Second.dat)
	public init?(iersLeapSecondDat text: String) {
		let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

		var expiry: JulianDayNumber?
		var leapSeconds: [LeapSecond] = []
		for line in text.split(whereSeparator: \.isNewline) {
			if line.hasPrefix("#") {
				// #  File expires on 28 June 2027
				let words = line.dropFirst().split(whereSeparator: \.isWhitespace)
				guard words.count >= 6, words[0] == "File", words[1] == "expires", words[2] == "on" else { continue }
				guard let day = Int(words[3]), let month = months.firstIndex(of: words[4].lowercased()), let year = Int(words[5]),
					  let jdn = try? GregorianCalendar.julianDayNumberFrom(year: year, month: month + 1, day: day)
				else { return nil }
				expiry = jdn
				continue
			}
			let fields = line.split(whereSeparator: \.isWhitespace)
			if fields.isEmpty { continue }
			// MJD, day, month, year, TAI - UTC, such as 41317.0 1 1 1972 10
			guard fields.count == 5, let mjd = Double(fields[0]), let mjdDay = Int(exactly: mjd),
				  let day = Int(fields[1]), let month = Int(fields[2]), let year = Int(fields[3]), let offset = Int(fields[4]),
				  let jdn = try? GregorianCalendar.julianDayNumberFrom(year: year, month: month, day: day)
			else { return nil }
			// MJD m starts at the midnight that begins civil day m + 2,400,001.
			let (mjdJDN, overflow) = mjdDay.addingReportingOverflow(2_400_001)
			guard !overflow, mjdJDN == jdn else { return nil }
			leapSeconds.append(LeapSecond(effective: jdn, taiMinusUTC: offset))
		}

		guard let expiry else { return nil }
		self.init(leapSeconds: leapSeconds, horizon: expiry)
	}
}
