#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Writes places seen from sites on the Earth, from ERFA and Skyfield, as a Swift test fixture.

The fixture holds the sites, then:

  The sites' positions in the ITRS from ERFA's gd2gce, and the geodetic coordinates that
  gc2gde recovers from them.

  The sites' positions and velocities relative to the geocenter in the GCRS, from ERFA's apco,
  with UT1 = TT - 69.2 s, no polar motion, and no celestial pole offsets, matching the models of
  EarthOrientation with a constant ΔT.

  Places of the stars of star-fixtures.py seen from the sites: starpm to the date, then pmpx
  for the astrometric direction and atciqn for the apparent one, with the Sun, Jupiter,
  Saturn, and the Earth of DE421 as deflectors, the observer from apco, and the apparent
  direction rotated back to the GCRS. The Earth deflects only stars above the horizon, the
  plane through the site perpendicular to the direction from the geocenter; light from below
  passes through the Earth.

  Places of bodies from Skyfield's wgs84 sites with the same ΔT: the apparent direction seen
  from the site and from the geocenter, whose difference, the diurnal parallax and aberration
  and the Earth's deflection, is mostly free of the differences between the ephemerides.

Requires:
  pyerfa 2.0.1.5 (ERFA 2.0.1), Skyfield 1.55, NumPy
  DE421: de421.bsp, from https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de421.bsp

Usage:
  Scripts/Fixtures/topocentric-fixtures.py de421.bsp \\
      Tests/AstronomiaTests/Astrometry/TopocentricFixtures.swift
"""

import math, sys
import numpy as np
import erfa
import skyfield
from skyfield.api import load_file, load, wgs84
if len(sys.argv) != 3:
	sys.exit("usage: Scripts/Fixtures/topocentric-fixtures.py DE421 OUTPUT")

eph = load_file(sys.argv[1])
DELTA_T = 69.2
ts = load.timescale(builtin=True, delta_t=DELTA_T)
C = erfa.DC
AU = erfa.DAU
MAS = math.pi / 180 / 3600 / 1000
GMS = 2.9591220836841438269e-4
GM = {
	"sun": GMS,
	"jupiter barycenter": 2.825345842083778e-7,
	"saturn barycenter": 8.4597151856806587398e-8,
	# The Earth: the Earth-Moon barycenter's INPOP10a value less the Moon's share
	"earth": 8.9970116036316091182e-10 * 81.30057 / (1 + 81.30057),
}

# name, latitude (deg), longitude (deg), height (m), ellipsoid
sites = [
	("greenwich", 51.4769, -0.0005, 46.0, "wgs84"),
	("maunaKea", 19.8207, -155.4681, 4205.0, "wgs84"),
	("concordia", -75.0999, 123.3326, 3233.0, "wgs84"),
	("quito", -0.2, -78.5, 2850.0, "grs80"),
	("deadSea", 31.5, 35.5, -430.0, "grs80"),
	("northPole", 90.0, 0.0, 0.0, "wgs84"),
]
ELLIPSOID = {"wgs84": erfa.WGS84, "grs80": erfa.GRS80}

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

# TT Julian Dates
dates = [2451545.0, 2460967.25, 2461334.75, 2469807.5]

def f(v):
	return "[" + ", ".join(repr(float(x)) for x in v) + "]"

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

def s2c(ra, dec):
	return np.array([math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec)])

# Geodetic conversions
geodetic = []
for i, (_, lat, lon, h, ell) in enumerate(sites):
	xyz = erfa.gd2gc(ELLIPSOID[ell], math.radians(lon), math.radians(lat), h)
	elong, phi, height = erfa.gc2gd(ELLIPSOID[ell], xyz)
	geodetic.append(f"\t({i}, {f(xyz)}, {float(phi)!r}, {float(elong)!r}, {float(height)!r}),")

states = []
star_places = []
body_places = []
bodies = [("sun", "sun"), ("moon", "moon"), ("mars", "mars"), ("jupiterBarycenter", "jupiter barycenter")]
for jd in dates:
	ut1 = (jd, -DELTA_T / 86400)
	tdb = (jd, float(erfa.dtdb(jd, 0.0, 0.5, 0.0, 0.0, 0.0)) / 86400)
	t = ts.tdb_jd(sum(tdb))
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
			# apco uses WGS84; the GRS80 sites are compared by their positions alone
			continue
		astrom = erfa.apco(tdb[0], tdb[1], pv(ebp, ebv), ehp, x, y, s, theta, math.radians(lon), math.radians(lat), h, 0.0, 0.0, sp, 0.0, 0.0)
		astrom["pmt"] = 0.0
		eb = astrom["eb"]
		v = astrom["v"] * C
		states.append(f"\t({i}, {jd!r}, {f((eb - ebp) * AU)}, {f((v - ebv) * AU / 86400)}),")
		bpn = astrom["bpn"]
		for j, star in enumerate(stars):
			_, _, _, pmra, pmdec, px, _, _ = star
			ra2, dec2, pmr2, pmd2, px2, rv2 = propagate(star, tdb)
			modeled = (px or 0.0) / 1000 >= effective_parallax(pmra, pmdec, px)
			pxo = px2 if modeled else (px or 0.0) / 1000
			astrometric = erfa.pmpx(ra2, dec2, pmr2, pmd2, pxo, rv2, 0.0, eb)
			up = eb - deflectors[3]["pv"]["p"]
			above = float(np.dot(astrometric, up)) >= 0
			ri, di = erfa.atciqn(ra2, dec2, pmr2, pmd2, pxo, rv2, astrom, deflectors if above else deflectors[:3])
			apparent = bpn.T @ s2c(float(ri), float(di))
			star_places.append(f"\t({i}, {jd!r}, {j}, {f(astrometric)}, {f(apparent)}),")
		site = wgs84.latlon(lat, lon, elevation_m=h)
		topocentric = eph["earth"] + site
		for name, key in bodies:
			geo = e.observe(eph[key]).apparent().position.au
			topo = topocentric.at(t).observe(eph[key]).apparent().position.au
			body_places.append(f"\t({i}, {jd!r}, .{name}, {f(geo)}, {f(topo)}),")

names = "\n".join(f"\t(\"{n}\", {lat!r}, {lon!r}, {h!r}, .{ell})," for n, lat, lon, h, ell in sites)
out = [
	"//", "// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>", "// SPDX-License-Identifier: MIT", "//",
	"// Part of https://github.com/sbooth/Astronomia", "//", "",
	"// Generated by Scripts/Fixtures/topocentric-fixtures.py. Do not edit.", "",
	"@testable import Astronomia", "",
	"/// Sites for the fixtures: the geodetic latitude and longitude, in degrees, the height, in",
	"/// meters, and the ellipsoid.",
	"let fixtureSites: [(name: String, latitude: Double, longitude: Double, height: Double, ellipsoid: Ellipsoid)] = [",
	names,
	"]", "",
	f"/// The sites' positions in the ITRS, in meters, from ERFA {erfa.version.erfa_version}'s gd2gce, and the",
	"/// geodetic latitude and longitude, in radians, and height, in meters, that gc2gde recovers.",
	"let erfaSiteGeodetic: [(site: Int, position: [Double], latitude: Double, longitude: Double, height: Double)] = [",
] + geodetic + ["]", "",
	f"/// The WGS84 sites' positions, in meters, and velocities, in m/s, relative to the geocenter in",
	f"/// the GCRS from ERFA's apco at TT Julian Dates, with UT1 = TT - {DELTA_T} s and no polar motion.",
	"let erfaSiteStates: [(site: Int, julianDate: Double, position: [Double], velocity: [Double])] = [",
] + states + ["]", "",
	"/// Places of the fixture stars seen from the WGS84 sites at TT Julian Dates: the astrometric",
	"/// direction from pmpx and the apparent direction from atciqn, with the Sun, Jupiter, Saturn,",
	"/// and the Earth of DE421 deflecting, rotated back to the GCRS, after starpm to the date.",
	"let erfaTopocentricStarPlaces: [(site: Int, julianDate: Double, star: Int, astrometric: [Double], apparent: [Double])] = [",
] + star_places + ["]", "",
	f"/// Apparent places of bodies from Skyfield {skyfield.__version__} and DE421 at TT Julian Dates, with ΔT = {DELTA_T} s:",
	"/// the geocentric position and the position seen from the WGS84 site, in au in the GCRS.",
	"let skyfieldTopocentricPlaces: [(site: Int, julianDate: Double, body: BuiltInEphemeris.Body, geocentric: [Double], topocentric: [Double])] = [",
] + body_places + ["]", ""]
open(sys.argv[2], "w").write("\n".join(out))
