#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Writes SPK files of the segment types other than 2 and 3, and their states from CSPICE.

Two files are written to Tests/AstronomiaTests/Fixtures:

  SPKTypes.bsp, by CSPICE's writers: Mars's barycenter relative to the Sun, from DE421 from
  October 2025, as discrete states in segments of type 8 (Lagrange, equal steps), 9
  (Lagrange, unequal steps), 12 (Hermite, equal steps), and 13 (Hermite, unequal steps),
  each with windows of an even and an odd number of states, and of type 9 in the ECLIPJ2000
  frame. The steps are days long and the polynomials of low degree, so that the states
  depend on which are interpolated. The unequal steps are 250 states, so the segments have
  an epoch directory.

  SPKDifferences.bsp, by a DAF writer in this script, as CSPICE has no writer for them:
  segments of type 1 and of type 21, modified difference arrays, whose records start at the
  same states, with difference tables made up for the test.

The states are each segment's body relative to the Sun, in the J2000 frame, in kilometers and
kilometers per second, from CSPICE's spkgeo at instants across each segment: its ends, the
epochs of some states or records, and instants between.

Requires:
  spiceypy 8.3.0 (CSPICE N0067), jplephem 2.24, NumPy
  DE421: de421.bsp, from https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de421.bsp

Usage:
  Scripts/Fixtures/spk-types-fixtures.py de421.bsp \\
      Tests/AstronomiaTests/Ephemerides/SPKTypeFixtures.swift

The states are written as a text fixture in Tests/AstronomiaTests/Fixtures, which the Swift
fixture reads when first used; see text_fixture.py.
"""

import os, struct, sys
import numpy as np
import spiceypy as sp
from jplephem.spk import SPK
import text_fixture
if len(sys.argv) != 3:
	sys.exit("usage: Scripts/Fixtures/spk-types-fixtures.py DE421 OUTPUT")

S_PER_DAY = 86400.0
J2000 = 2451545.0
fixtures = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[2]))), "Fixtures")
types_path = os.path.join(fixtures, "SPKTypes.bsp")
differences_path = os.path.join(fixtures, "SPKDifferences.bsp")

de421 = SPK.open(sys.argv[1])
def mars(seconds):
	"""Mars's barycenter relative to the Sun, in km and km/s."""
	jd2 = seconds / S_PER_DAY
	p4, v4 = de421[0, 4].compute_and_differentiate(J2000, jd2)
	p10, v10 = de421[0, 10].compute_and_differentiate(J2000, jd2)
	return list(p4 - p10) + list((v4 - v10) / S_PER_DAY)

start = (2460963.5 - J2000) * S_PER_DAY  # 2025 October 15
rng = np.random.default_rng(2026)

# Discrete states: 41 at equal steps of 4 days, and 250 at unequal steps of 1 to 3 days
step = 4 * S_PER_DAY
equal = [start + k * step for k in range(41)]
unequal = list(start + np.cumsum(np.concatenate([[0], rng.uniform(1, 3, 249)])) * S_PER_DAY)
eclip = sp.pxform("J2000", "ECLIPJ2000", 0)

for path in (types_path, differences_path):
	if os.path.exists(path):
		os.remove(path)
handle = sp.spkopn(types_path, "Astronomia SPK types", 0)
sp.spkw08(handle, 1008, 10, "J2000", equal[0], equal[-1], "type 8", 3, len(equal), [mars(t) for t in equal], equal[0], step)
sp.spkw09(handle, 1009, 10, "J2000", unequal[0], unequal[-1], "type 9", 3, len(unequal), [mars(t) for t in unequal], unequal)
sp.spkw12(handle, 1012, 10, "J2000", equal[0], equal[-1], "type 12", 3, len(equal), [mars(t) for t in equal], equal[0], step)
sp.spkw13(handle, 1013, 10, "J2000", unequal[0], unequal[-1], "type 13", 3, len(unequal), [mars(t) for t in unequal], unequal)
ecliptic = []
for t in unequal:
	s = mars(t)
	ecliptic.append(list(eclip @ np.array(s[:3])) + list(eclip @ np.array(s[3:])))
sp.spkw09(handle, 1017, 10, "ECLIPJ2000", unequal[0], unequal[-1], "type 9 ecliptic", 5, len(unequal), ecliptic, unequal)
# Windows of odd sizes, which are centered on the nearest state: Lagrange of degree 2, 3
# states, and Hermite of degree 5, 3 states
sp.spkw08(handle, 1108, 10, "J2000", equal[0], equal[-1], "type 8 odd", 2, len(equal), [mars(t) for t in equal], equal[0], step)
sp.spkw09(handle, 1109, 10, "J2000", unequal[0], unequal[-1], "type 9 odd", 2, len(unequal), [mars(t) for t in unequal], unequal)
sp.spkw12(handle, 1112, 10, "J2000", equal[0], equal[-1], "type 12 odd", 5, len(equal), [mars(t) for t in equal], equal[0], step)
sp.spkw13(handle, 1113, 10, "J2000", unequal[0], unequal[-1], "type 13 odd", 5, len(unequal), [mars(t) for t in unequal], unequal)
sp.spkcls(handle)


def mda_records(dimension, count, kq):
	"""Records of modified difference arrays: the final epoch, the step sizes, the reference
	position and velocity interleaved, the difference table by component, the maximum
	integration order plus 1, and the integration order of each component."""
	records, epochs = [], []
	for k in range(count):
		tl = start + (k + 1) * S_PER_DAY
		state = mars(tl)
		g = [S_PER_DAY * (0.5 + 0.25 * j) for j in range(dimension)]
		reference = [state[0], state[3], state[1], state[4], state[2], state[5]]
		dt = []
		for i in range(3):
			dt += [float(rng.uniform(-1, 1)) * 2e-9 * 0.3 ** j for j in range(dimension)]
		records.append([tl] + g + reference + dt + [float(max(kq) + 1)] + [float(q) for q in kq])
		epochs.append(tl)
	return records, epochs


def daf(path, segments):
	"""Writes an SPK file of segments of (target, center, frame, type, start, end, name,
	words) by the DAF format: the file record, one summary record, one name record, then the
	data."""
	record = 1024
	words_before = 3 * 128
	summaries, names, data = [], [], []
	address = words_before + 1
	for target, center, frame, kind, first, last, name, words in segments:
		end = address + len(words) - 1
		summaries.append(struct.pack("<2d6i", first, last, target, center, frame, kind, address, end))
		names.append(name.ljust(40).encode())
		data += words
		address = end + 1
	ftp = b"FTPSTR:\r:\n:\r\n:\r\x00:\x81:\x10\xce:ENDFTP"
	header = b"DAF/SPK " + struct.pack("<ii", 2, 6) + b"Astronomia SPK types".ljust(60) + struct.pack("<iii", 2, 2, address)
	header += b"LTL-IEEE" + bytes(603) + ftp
	header += bytes(record - len(header))
	summary = struct.pack("<3d", 0, 0, len(segments)) + b"".join(summaries)
	summary += bytes(record - len(summary))
	name_record = b"".join(names).ljust(record)
	body = struct.pack(f"<{len(data)}d", *data)
	# Whole records, as CSPICE reads them
	body += bytes(-len(body) % record)
	with open(path, "wb") as file:
		file.write(header + summary + name_record + body)


# Type 1: 30 records of dimension 15; type 21: of dimension 18, past type 1's 15
records1, epochs1 = mda_records(15, 30, (12, 11, 10))
records21, epochs21 = mda_records(18, 30, (17, 16, 15))
words1 = [w for r in records1 for w in r] + epochs1 + [float(len(records1))]
words21 = [w for r in records21 for w in r] + epochs21 + [18.0, float(len(records21))]
segment_start = start + 0.25 * S_PER_DAY
daf(differences_path, [
	(1001, 10, 1, 1, segment_start, epochs1[-1], "type 1", words1),
	(1021, 10, 1, 21, segment_start, epochs21[-1], "type 21", words21),
])

# The states from CSPICE
sp.furnsh(types_path)
sp.furnsh(differences_path)
rows = []
def instants(first, last, epochs):
	chosen = {first, last} | set(epochs[1:4]) | set(epochs[-3:])
	chosen |= {first + f * (last - first) for f in (0.0123, 0.25, 0.5, 0.6789, 0.9876)}
	chosen |= {a + 0.37 * (b - a) for a, b in zip(epochs[5:8], epochs[6:9])}
	# Midway between states, where the nearest state changes
	chosen |= {(a + b) / 2 for a, b in zip(epochs[10:13], epochs[11:14])}
	return sorted(t for t in chosen if first <= t <= last)
segments = [
	(1008, equal[0], equal[-1], equal),
	(1009, unequal[0], unequal[-1], unequal),
	(1012, equal[0], equal[-1], equal),
	(1013, unequal[0], unequal[-1], unequal),
	(1017, unequal[0], unequal[-1], unequal),
	(1108, equal[0], equal[-1], equal),
	(1109, unequal[0], unequal[-1], unequal),
	(1112, equal[0], equal[-1], equal),
	(1113, unequal[0], unequal[-1], unequal),
	(1001, segment_start, epochs1[-1], epochs1),
	(1021, segment_start, epochs21[-1], epochs21),
]
for body, first, last, epochs in segments:
	for t in instants(first, last, epochs):
		state, _ = sp.spkgeo(body, t, "J2000", 10)
		rows.append((body, t, [float(v) for v in state[:3]], [float(v) for v in state[3:]]))
sp.kclear()

out = [
	"//",
	"// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>",
	"// SPDX-License-Identifier: MIT",
	"//",
	"// Part of https://github.com/sbooth/Astronomia",
	"//",
	"",
	"// Generated by Scripts/Fixtures/spk-types-fixtures.py. Do not edit.",
	"",
	f"/// States of the segments of Fixtures/SPKTypes.bsp and Fixtures/SPKDifferences.bsp, from CSPICE",
	f"/// {sp.tkvrsn('TOOLKIT')}: the body, TDB seconds from J2000.0, and the body's position, in km, and",
	"/// velocity, in km/s, relative to the Sun in the J2000 frame. The bodies are 1008, 1009, 1012,",
	"/// and 1013 for types 8, 9, 12, and 13 with windows of even sizes, 1108, 1109, 1112, and 1113",
	"/// with windows of odd sizes, 1017 for type 9 in ECLIPJ2000, and 1001 and 1021 for types 1",
	"/// and 21.",
	"let cspiceSPKTypeStates: [(body: Int, seconds: Double, position: [Double], velocity: [Double])] = textFixture(\"CspiceSPKTypeStates\") { row in",
	"\t(row.int(), row.double(), row.vector(), row.vector())",
	"}",
	"",
]
open(sys.argv[2], "w").write("\n".join(out))
text_fixture.write(sys.argv[2], "cspiceSPKTypeStates", "Scripts/Fixtures/spk-types-fixtures.py", "body seconds position.x position.y position.z velocity.x velocity.y velocity.z", rows)
