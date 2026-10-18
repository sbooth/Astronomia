//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// The data and #$, #@, and #h lines of the IERS/IETF `leap-seconds.list` updated 2026-07-06.
let leapSecondsListText = """
#$\t3992312697
#@\t4023129600
2272060800      10      # 1 Jan 1972
2287785600      11      # 1 Jul 1972
2303683200      12      # 1 Jan 1973
2335219200      13      # 1 Jan 1974
2366755200      14      # 1 Jan 1975
2398291200      15      # 1 Jan 1976
2429913600      16      # 1 Jan 1977
2461449600      17      # 1 Jan 1978
2492985600      18      # 1 Jan 1979
2524521600      19      # 1 Jan 1980
2571782400      20      # 1 Jul 1981
2603318400      21      # 1 Jul 1982
2634854400      22      # 1 Jul 1983
2698012800      23      # 1 Jul 1985
2776982400      24      # 1 Jan 1988
2840140800      25      # 1 Jan 1990
2871676800      26      # 1 Jan 1991
2918937600      27      # 1 Jul 1992
2950473600      28      # 1 Jul 1993
2982009600      29      # 1 Jul 1994
3029443200      30      # 1 Jan 1996
3076704000      31      # 1 Jul 1997
3124137600      32      # 1 Jan 1999
3345062400      33      # 1 Jan 2006
3439756800      34      # 1 Jan 2009
3550089600      35      # 1 Jul 2012
3644697600      36      # 1 Jul 2015
3692217600      37      # 1 Jan 2017
#h\ta9bad145 84c31c70 758402aa b37bfd54 5923836a
"""

/// The IERS `Leap_Second.dat` updated through Bulletin C 72.
let iersLeapSecondDatText = """
#  Value of TAI-UTC in second valid beetween the initial value until
#  the epoch given on the next line. The last line reads that NO
#  leap second was introduced since the corresponding date
#  Updated through IERS Bulletin 72 issued in July 2026
#
#
#  File expires on 28 June 2027
#
#
#    MJD        Date        TAI-UTC (s)
#           day month year
#    ---    --------------   ------
#
    41317.0    1  1 1972       10
    41499.0    1  7 1972       11
    41683.0    1  1 1973       12
    42048.0    1  1 1974       13
    42413.0    1  1 1975       14
    42778.0    1  1 1976       15
    43144.0    1  1 1977       16
    43509.0    1  1 1978       17
    43874.0    1  1 1979       18
    44239.0    1  1 1980       19
    44786.0    1  7 1981       20
    45151.0    1  7 1982       21
    45516.0    1  7 1983       22
    46247.0    1  7 1985       23
    47161.0    1  1 1988       24
    47892.0    1  1 1990       25
    48257.0    1  1 1991       26
    48804.0    1  7 1992       27
    49169.0    1  7 1993       28
    49534.0    1  7 1994       29
    50083.0    1  1 1996       30
    50630.0    1  7 1997       31
    51179.0    1  1 1999       32
    53736.0    1  1 2006       33
    54832.0    1  1 2009       34
    56109.0    1  7 2012       35
    57204.0    1  7 2015       36
    57754.0    1  1 2017       37
"""

@Suite struct LeapSecondFileTests {
	@Test func leapSecondsList() throws {
		let table = try #require(LeapSecondTable(leapSecondsList: leapSecondsListText))
		#expect(table.leapSeconds == LeapSecondTable.builtIn.leapSeconds)
		// The file expires at 0h UTC on 2027-06-28, which is the horizon, as for the built-in
		// table generated from the same file.
		#expect(try table.horizon == civilDay(2027, 6, 28))
		#expect(table == LeapSecondTable.builtIn)
	}

	@Test func iersLeapSecondDat() throws {
		let table = try #require(LeapSecondTable(iersLeapSecondDat: iersLeapSecondDatText))
		#expect(table.leapSeconds == LeapSecondTable.builtIn.leapSeconds)
		#expect(try table.horizon == civilDay(2027, 6, 28))
		#expect(table == LeapSecondTable(leapSecondsList: leapSecondsListText))
	}

	@Test func malformedLeapSecondsList() {
		/// Returns `leapSecondsListText` with `old` replaced by `new`.
		func replacing(_ old: String, with new: String) -> String {
			let lines = leapSecondsListText.split(separator: "\n", omittingEmptySubsequences: false)
			return lines.map { $0.hasPrefix(old) ? new : String($0) }.joined(separator: "\n")
		}
		// No expiry
		#expect(LeapSecondTable(leapSecondsList: replacing("#@", with: "#")) == nil)
		#expect(LeapSecondTable(leapSecondsList: replacing("#@", with: "#@\tsoon")) == nil)
		// Not the start of a UTC day, or not numbers
		#expect(LeapSecondTable(leapSecondsList: replacing("2287785600", with: "2287785601\t11")) == nil)
		#expect(LeapSecondTable(leapSecondsList: replacing("2287785600", with: "2287785600\televen")) == nil)
		#expect(LeapSecondTable(leapSecondsList: replacing("2287785600", with: "2287785600")) == nil)
		// Not starting at 1972-01-01 with 10 s
		#expect(LeapSecondTable(leapSecondsList: replacing("2272060800", with: "#")) == nil)
		// Expiring before the last leap second
		#expect(LeapSecondTable(leapSecondsList: replacing("#@", with: "#@\t3692217600")) == nil)
	}

	@Test func malformedIERSLeapSecondDat() {
		/// Returns `iersLeapSecondDatText` with each line beginning `old`, after any spaces,
		/// replaced by `new`, or removed if `new` is `nil`.
		func replacing(_ old: String, with new: String?) -> String {
			let lines = iersLeapSecondDatText.split(separator: "\n", omittingEmptySubsequences: false)
			return lines.compactMap { $0.drop { $0 == " " }.hasPrefix(old) ? new : String($0) }.joined(separator: "\n")
		}
		#expect(LeapSecondTable(iersLeapSecondDat: replacing("#  File expires", with: "#  File valid until 28 June 2027")) == nil)
		#expect(LeapSecondTable(iersLeapSecondDat: replacing("#  File expires", with: "#  File expires on 28 Juin 2027")) == nil)
		// The MJD does not match the date, or a value is not a number
		#expect(LeapSecondTable(iersLeapSecondDat: replacing("41499.0", with: "41498.0    1  7 1972       11")) == nil)
		#expect(LeapSecondTable(iersLeapSecondDat: replacing("41499.0", with: "41499.0    1  7 1972       x")) == nil)
		// Not starting at 1972-01-01 with 10 s
		#expect(LeapSecondTable(iersLeapSecondDat: replacing("41317.0", with: nil)) == nil)
	}
}
