#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Writes observed places from ERFA and Skyfield, and ERFA's refraction constants, as a Swift
test fixture.

The fixture holds:

  ERFA's refco refraction constants for a range of conditions.

  Observed places of the stars of star-fixtures.py from the WGS84 sites of
  topocentric-fixtures.py: the apparent place in the CIRS from apco and atciqn, as in
  topocentric-fixtures.py, then the azimuth, zenith distance, hour angle, and declination from
  atioq, without refraction and with refraction for three sets of conditions. UT1 is
  TT - 69.2 s, and the polar motion is a constant x_p = 0.12", y_p = 0.34".

  Places of bodies from Skyfield's wgs84 sites with the same UT1 and no polar motion: the
  apparent topocentric position in the GCRS, and the altitude, azimuth, hour angle, and
  declination Skyfield finds from it, without refraction.

Requires:
  pyerfa 2.0.1.5 (ERFA 2.0.1), Skyfield 1.55, NumPy
  DE421: de421.bsp, from https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de421.bsp

Usage:
  Scripts/Fixtures/observed-fixtures.py de421.bsp \\
      Tests/AstronomiaTests/Astrometry/ObservedFixtures.swift

The large tables are written as text fixtures in Tests/AstronomiaTests/Fixtures, which the
Swift fixture reads when first used; see text_fixture.py.
"""

import math, sys
import text_fixture
import numpy as np
import erfa
import skyfield
from skyfield.api import load_file, load, wgs84
if len(sys.argv) != 3:
	sys.exit("usage: Scripts/Fixtures/observed-fixtures.py DE421 OUTPUT")

eph = load_file(sys.argv[1])
DELTA_T = 69.2
XP = 0.12 / 206264.80624709636
YP = 0.34 / 206264.80624709636
ts = load.timescale(builtin=True, delta_t=DELTA_T)
MAS = math.pi / 180 / 3600 / 1000
GMS = 2.9591220836841438269e-4
GM = {
	"sun": GMS,
	"jupiter barycenter": 2.825345842083778e-7,
	"saturn barycenter": 8.4597151856806587398e-8,
	"earth": 8.9970116036316091182e-10 * 81.30057 / (1 + 81.30057),
}

# The sites of topocentric-fixtures.py, in the same order
sites = [
	("greenwich", 51.4769, -0.0005, 46.0, "wgs84"),
	("maunaKea", 19.8207, -155.4681, 4205.0, "wgs84"),
	("concordia", -75.0999, 123.3326, 3233.0, "wgs84"),
	("quito", -0.2, -78.5, 2850.0, "grs80"),
	("deadSea", 31.5, 35.5, -430.0, "grs80"),
	("northPole", 90.0, 0.0, 0.0, "wgs84"),
]

# The stars of star-fixtures.py, in the same order
stars = [
	("barnard", 269.45207511, 4.69339088, -801.551, 10362.394, 548.31, -110.51, 1991.25),
	("proxima", 217.39232147, -62.67607512, -3781.306, 769.766, 768.0665, -21.7, 2016.0),
	("sirius", 101.28715533, -16.71611586, -546.01, -1223.07, 379.21, -5.5, 1991.25),
	("polaris", 37.95456067, 89.26410897, 44.48, -11.85, 7.54, -17.4, 1991.25),
	("arcturus", 213.91530029, 19.18240916, -1093.39, -2000.06, 88.83, -5.19, 1991.25),
	("quasar", 187.27791535, 2.05238857, 0.0, 0.0, None, 0.0, 2000.0),
	("noParallax", 10.0, -30.0, 30.0, -40.0, None, 0.0, 2016.0),
	("smallParallax", 300.0, 45.0, 400.0, 300.0, 0.05, 12.0, 2016.0),
	("southPole", 0.5, -89.9, 100.0, 200.0, 10.0, 20.0, 2000.0),
]

# Pressure (hPa), temperature (°C), relative humidity, wavelength (µm); None for no refraction
conditions = [
	None,
	(1013.25, 10.0, 0.5, 0.55),
	(615.0, -5.0, 0.1, 0.8),
	(1000.0, 30.0, 0.9, 20000.0),
]

# refco inputs: the conditions above, and extremes of each value
refco_inputs = [c for c in conditions if c] + [
	(0.0, 10.0, 0.5, 0.55),
	(10000.0, -150.0, 0.0, 0.1),
	(700.0, 35.0, 1.0, 100.0),
	(700.0, 35.0, 1.0, 100.000001),
	(1013.25, 0.0, 0.0, 1e6),
	(800.0, 25.0, 1.0, 2.2),
]

# TT Julian Dates
dates = [2451545.0, 2460967.25, 2461334.75, 2469807.5]

def pv(p, v):
	result = np.zeros((), dtype=erfa.dt_pv)
	result["p"] = p
	result["v"] = v
	return result

def effective_parallax(pmra, pmdec, px):
	"""The parallax used for the space motion, in arcseconds, as in Star.effectiveParallax."""
	pm = math.hypot(pmra, pmdec) * MAS
	return max((px or 0.0) / 1000, pm * 326, 1e-9)

def propagate(star, to_jd):
	_, ra, dec, pmra, pmdec, px, rv, epoch = star
	ra, dec = math.radians(ra), math.radians(dec)
	e1a, e1b = erfa.epj2jd(epoch)
	ra2, dec2, pmr2, pmd2, px2, rv2 = erfa.starpm(ra, dec, pmra * MAS / math.cos(dec), pmdec * MAS, effective_parallax(pmra, pmdec, px), rv, e1a, e1b, to_jd[0], to_jd[1])
	return float(ra2), float(dec2), float(pmr2), float(pmd2), float(px2), float(rv2)

refco = []
for c in refco_inputs:
	a, b = erfa.refco(*c)
	refco.append(f"\t({c[0]!r}, {c[1]!r}, {c[2]!r}, {c[3]!r}, {float(a)!r}, {float(b)!r}),")

star_places = []
body_places = []
bodies = [("sun", "sun"), ("moon", "moon"), ("mars", "mars"), ("jupiterBarycenter", "jupiter barycenter")]
for jd in dates:
	ut1 = (jd, -DELTA_T / 86400)
	tdb = (jd, float(erfa.dtdb(jd, 0.0, 0.5, 0.0, 0.0, 0.0)) / 86400)
	# The TT Julian Date itself: a single float of TDB would round the instant by up to 20 µs,
	# which turns the Earth by 0.3 mas.
	t = ts.tt_jd(jd)
	e = eph["earth"].at(t)
	ebp, ebv = e.position.au, e.velocity.au_per_d
	ehp = ebp - eph["sun"].at(t).position.au
	x, y, s = erfa.xys06a(jd, 0.0)
	theta = erfa.era00(*ut1)
	sp = erfa.sp00(jd, 0.0)
	deflectors = np.zeros(4, dtype=erfa.dt_eraLDBODY)
	for k, name in enumerate(("saturn barycenter", "jupiter barycenter", "sun", "earth")):
		b = eph[name].at(t)
		deflectors[k]["bm"] = GM[name] / GMS
		deflectors[k]["dl"] = 6e-6 if name == "sun" else 1e-12 if name == "earth" else 3e-9
		deflectors[k]["pv"] = pv(b.position.au, b.velocity.au_per_d)
	for i, (_, lat, lon, h, ell) in enumerate(sites):
		if ell != "wgs84":
			continue
		for k, c in enumerate(conditions):
			refa, refb = erfa.refco(*c) if c else (0.0, 0.0)
			astrom = erfa.apco(tdb[0], tdb[1], pv(ebp, ebv), ehp, x, y, s, theta, math.radians(lon), math.radians(lat), h, XP, YP, sp, refa, refb)
			astrom["pmt"] = 0.0
			eb = astrom["eb"]
			for j, star in enumerate(stars):
				_, _, _, pmra, pmdec, px, _, _ = star
				ra2, dec2, pmr2, pmd2, px2, rv2 = propagate(star, tdb)
				modeled = (px or 0.0) / 1000 >= effective_parallax(pmra, pmdec, px)
				pxo = px2 if modeled else (px or 0.0) / 1000
				astrometric = erfa.pmpx(ra2, dec2, pmr2, pmd2, pxo, rv2, 0.0, eb)
				above = float(np.dot(astrometric, eb - deflectors[3]["pv"]["p"])) >= 0
				ri, di = erfa.atciqn(ra2, dec2, pmr2, pmd2, pxo, rv2, astrom, deflectors if above else deflectors[:3])
				aob, zob, hob, dob, rob = erfa.atioq(ri, di, astrom)
				star_places.append((i, jd, j, k, float(aob), float(zob), float(hob), float(dob)))
		site = wgs84.latlon(lat, lon, elevation_m=h)
		topocentric = eph["earth"] + site
		for name, key in bodies:
			apparent = topocentric.at(t).observe(eph[key]).apparent()
			alt, az, distance = apparent.altaz()
			ha, dec, _ = apparent.hadec()
			body_places.append((i, jd, name, apparent.position.au, float(alt.radians), float(az.radians), float(ha.radians), float(dec.radians)))

out = [
	"//", "// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>", "// SPDX-License-Identifier: MIT", "//",
	"// Part of https://github.com/sbooth/Astronomia", "//", "",
	"// Generated by Scripts/Fixtures/observed-fixtures.py. Do not edit.", "",
	"@testable import Astronomia", "",
	"/// The conditions of the fixtures: pressure, in hPa, temperature, in °C, relative humidity,",
	"/// and wavelength, in µm; `nil` for no refraction.",
	"let fixtureConditions: [(pressure: Double, temperature: Double, relativeHumidity: Double, wavelength: Double)?] = [",
] + [f"\t({c[0]!r}, {c[1]!r}, {c[2]!r}, {c[3]!r})," if c else "\tnil," for c in conditions] + ["]", "",
	f"/// Refraction constants A and B, in radians, from ERFA {erfa.version.erfa_version}'s refco for pressure, in hPa,",
	"/// temperature, in °C, relative humidity, and wavelength, in µm.",
	"let erfaRefractionConstants: [(pressure: Double, temperature: Double, relativeHumidity: Double, wavelength: Double, a: Double, b: Double)] = [",
] + refco + ["]", "",
	"/// Observed places of the fixture stars from the WGS84 sites at TT Julian Dates under each of",
	"/// the fixture conditions, from ERFA's atioq after apco and atciqn, with UT1 = TT - 69.2 s and",
	"/// polar motion of 0.12\" and 0.34\": the azimuth, zenith distance, hour angle, and",
	"/// declination, in radians.",
	"let erfaObservedStarPlaces: [(site: Int, julianDate: Double, star: Int, conditions: Int, azimuth: Double, zenithDistance: Double, hourAngle: Double, declination: Double)] = textFixture(\"ErfaObservedStarPlaces\") { row in",
	"\t(row.int(), row.double(), row.int(), row.int(), row.double(), row.double(), row.double(), row.double())",
	"}", "",
	f"/// Places of bodies from Skyfield {skyfield.__version__} and DE421 seen from the WGS84 sites at TT Julian",
	f"/// Dates, with ΔT = {DELTA_T} s and no polar motion: the apparent position, in au in the GCRS, and",
	"/// the altitude, azimuth, hour angle, and declination, in radians, without refraction.",
	"let skyfieldObservedPlaces: [(site: Int, julianDate: Double, body: BuiltInEphemeris.Body, apparent: [Double], altitude: Double, azimuth: Double, hourAngle: Double, declination: Double)] = textFixture(\"SkyfieldObservedPlaces\") { row in",
	"\t(row.int(), row.double(), row.value(), row.vector(), row.double(), row.double(), row.double(), row.double())",
	"}", ""
]
open(sys.argv[2], "w").write("\n".join(out))
text_fixture.write(sys.argv[2], "erfaObservedStarPlaces", "Scripts/Fixtures/observed-fixtures.py", "site julianDate star conditions azimuth zenithDistance hourAngle declination", star_places)
text_fixture.write(sys.argv[2], "skyfieldObservedPlaces", "Scripts/Fixtures/observed-fixtures.py", "site julianDate body apparent.x apparent.y apparent.z altitude azimuth hourAngle declination", body_places)
