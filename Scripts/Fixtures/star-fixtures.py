#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Writes star motion and places from ERFA and Skyfield, with DE421, as a Swift test fixture.

The fixture holds the stars, then:

  The stars carried to other Julian epochs by ERFA's starpm, with the parallax that
  Star.effectiveParallax uses.

  Geocentric places from ERFA. ERFA's atci13 assumes a J2000 catalog and moves the star to
  first order, so the places are built from parts instead: starpm to the date, then pmpx
  and atciqn with pmt = 0, using apci with DE421's Earth and the Sun, Jupiter and Saturn of
  DE421 as deflectors, and the apparent direction rotated back to the GCRS by the inverse
  of the bias-precession-nutation matrix.

  Geocentric places from Skyfield's Star for the stars without radial velocity, where its
  model agrees with ERFA's.

Requires:
  pyerfa 2.0.1.5 (ERFA 2.0.1), Skyfield 1.55, NumPy
  DE421: de421.bsp, from https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de421.bsp

Usage:
  Scripts/Fixtures/star-fixtures.py de421.bsp \\
      Tests/AstronomiaTests/Astrometry/StarFixtures.swift

The large tables are written as text fixtures in Tests/AstronomiaTests/Fixtures, which the
Swift fixture reads when first used; see text_fixture.py.
"""

import math, sys
import text_fixture
import numpy as np
import erfa
import skyfield
from skyfield.api import load_file, load, Star
from skyfield.units import Angle as SAngle
if len(sys.argv) != 3:
	sys.exit("usage: Scripts/Fixtures/star-fixtures.py DE421 OUTPUT")


eph = load_file(sys.argv[1])
ts = load.timescale(builtin=True)
MAS = math.pi / 180 / 3600 / 1000
C = erfa.DC  # au/day

# name, RA (deg), Dec (deg), pmRA* (mas/yr), pmDec (mas/yr), parallax (mas) or None, RV (km/s), Julian epoch
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

def effective_parallax(pmra, pmdec, px):
	"""The parallax used for the space motion, in arcseconds, as in Star.effectiveParallax."""
	pm = math.hypot(pmra, pmdec) * MAS  # rad/yr
	return max((px or 0.0) / 1000, pm * 326, 1e-9)

def epoch_jd(year):
	a, b = erfa.epj2jd(year)
	return float(a), float(b)

def propagate(star, to_jd):
	_, ra, dec, pmra, pmdec, px, rv, epoch = star
	ra, dec = math.radians(ra), math.radians(dec)
	pmr = pmra * MAS / math.cos(dec)
	pmd = pmdec * MAS
	e1a, e1b = epoch_jd(epoch)
	ra2, dec2, pmr2, pmd2, px2, rv2 = erfa.starpm(ra, dec, pmr, pmd, effective_parallax(pmra, pmdec, px), rv, e1a, e1b, to_jd[0], to_jd[1])
	return float(ra2), float(dec2), float(pmr2) * math.cos(float(dec2)), float(pmd2), float(px2), float(rv2)

def pv(p, v):
	result = np.zeros((), dtype=erfa.dt_pv)
	result["p"] = p
	result["v"] = v
	return result

def unit(v):
	return v / np.linalg.norm(v)

def s2c(ra, dec):
	return np.array([math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec)])

# Motion between epochs
motion = []
for i, star in enumerate(stars):
	for year in (1900.0, 2000.0, 2026.8, 2100.0):
		ra2, dec2, pma, pmd, px2, rv2 = propagate(star, epoch_jd(year))
		motion.append((i, year, ra2, dec2, pma, pmd, px2, rv2))

# Places, from ERFA with the Earth and bodies of DE421
gm = {"sun": 1.0, "jupiter barycenter": 1 / 1047.348644, "saturn barycenter": 1 / 3497.9018}
dates = [2433282.5, 2451545.0, 2460967.25, 2461334.5, 2469807.5]
erfa_places = []
sky_places = []
earth = eph["earth"]
for jd in dates:
	t = ts.tdb_jd(jd)
	e = earth.at(t)
	ebp, ebv = e.position.au, e.velocity.au_per_d
	sun = eph["sun"].at(t)
	ehp = ebp - sun.position.au
	x, y, s = erfa.xys06a(jd, 0.0)
	astrom = erfa.apci(jd, 0.0, pv(ebp, ebv), ehp, x, y, s)
	astrom["pmt"] = 0.0
	bodies = np.zeros(3, dtype=erfa.dt_eraLDBODY)
	for k, name in enumerate(("jupiter barycenter", "saturn barycenter", "sun")):
		b = eph[name].at(t)
		bodies[k]["bm"] = gm[name]
		bodies[k]["dl"] = 6e-6 if name == "sun" else 3e-9
		bodies[k]["pv"] = pv(b.position.au, b.velocity.au_per_d)
	bpn = astrom["bpn"]
	for i, star in enumerate(stars):
		_, _, _, _, _, px, _, _ = star
		ra2, dec2, pma, pmd, px2, rv2 = propagate(star, (jd, 0.0))
		pmr = pma / math.cos(dec2)
		# The catalog's parallax for a star whose distance is modeled, as in Star.hasDistance
		modeled = (px or 0.0) / 1000 >= effective_parallax(star[3], star[4], px)
		pxo = px2 if modeled else (px or 0.0) / 1000
		astrometric = erfa.pmpx(ra2, dec2, pmr, pmd, pxo, rv2, 0.0, ebp)
		ri, di = erfa.atciqn(ra2, dec2, pmr, pmd, pxo, rv2, astrom, bodies)
		apparent = bpn.T @ s2c(float(ri), float(di))
		erfa_places.append((i, jd, astrometric, apparent))

		# Skyfield, with no radial velocity, where its model and ERFA's agree
		_, ra, dec, pmra, pmdec, px, _, epoch = star
		sky = Star(ra=SAngle(degrees=ra), dec=SAngle(degrees=dec), ra_mas_per_year=pmra, dec_mas_per_year=pmdec,
			parallax_mas=px or 0.0, radial_km_per_s=0.0, epoch=sum(epoch_jd(epoch)))
		observed = e.observe(sky)
		a = observed.position.au
		p = observed.apparent().position.au
		sky_places.append((i, jd, a, float(observed.light_time), p))

names = "\n".join(f"\t({n!r}".replace("'", '"') + f", {ra!r}, {dec!r}, {pmra!r}, {pmdec!r}, {('nil' if px is None else repr(px))}, {rv!r}, {ep!r})," for n, ra, dec, pmra, pmdec, px, rv, ep in stars)
out = [
	"//", "// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>", "// SPDX-License-Identifier: MIT", "//",
	"// Part of https://github.com/sbooth/Astronomia", "//", "",
	"// Generated by Scripts/Fixtures/star-fixtures.py. Do not edit.", "",
	"@testable import Astronomia", "",
	"/// Stars for the fixtures: the right ascension and declination, in degrees, the proper",
	"/// motions, in mas/yr, the parallax, in mas, the radial velocity, in km/s, and the Julian",
	"/// epoch.",
	"let fixtureStars: [(name: String, rightAscension: Double, declination: Double, properMotionInRightAscension: Double, properMotionInDeclination: Double, parallax: Double?, radialVelocity: Double, julianEpoch: Double)] = [",
	names,
	"]", "",
	f"/// Stars carried to other Julian epochs by ERFA {erfa.version.erfa_version}'s starpm, with the parallax of",
	"/// Star.effectiveParallax: the right ascension and declination, the proper motions, in",
	"/// radians, per Julian year, the parallax, in arcseconds, and the radial velocity, in km/s.",
	"let erfaStarMotion: [(star: Int, julianEpoch: Double, rightAscension: Double, declination: Double, properMotionInRightAscension: Double, properMotionInDeclination: Double, parallax: Double, radialVelocity: Double)] = textFixture(\"ErfaStarMotion\") { row in",
	"\t(row.int(), row.double(), row.double(), row.double(), row.double(), row.double(), row.double(), row.double())",
	"}", "",
	"/// Geocentric places of stars from ERFA, with the Earth, Sun, Jupiter, and Saturn of DE421, at",
	"/// TDB Julian Dates: the astrometric direction from pmpx, and the apparent direction from",
	"/// atciqn rotated back to the GCRS, after starpm to the date.",
	"let erfaStarPlaces: [(star: Int, julianDate: Double, astrometric: [Double], apparent: [Double])] = textFixture(\"ErfaStarPlaces\") { row in",
	"\t(row.int(), row.double(), row.vector(), row.vector())",
	"}", "",
	f"/// Geocentric places of stars without radial velocity from Skyfield {skyfield.__version__} and DE421 at TDB",
	"/// Julian Dates: the astrometric position, in au, its light time, in days, and the apparent",
	"/// position.",
	"let skyfieldStarPlaces: [(star: Int, julianDate: Double, astrometric: [Double], lightTime: Double, apparent: [Double])] = textFixture(\"SkyfieldStarPlaces\") { row in",
	"\t(row.int(), row.double(), row.vector(), row.double(), row.vector())",
	"}", ""
]
open(sys.argv[2], "w").write("\n".join(out))
text_fixture.write(sys.argv[2], "erfaStarMotion", "Scripts/Fixtures/star-fixtures.py", "star julianEpoch rightAscension declination properMotionInRightAscension properMotionInDeclination parallax radialVelocity", motion)
text_fixture.write(sys.argv[2], "erfaStarPlaces", "Scripts/Fixtures/star-fixtures.py", "star julianDate astrometric.x astrometric.y astrometric.z apparent.x apparent.y apparent.z", erfa_places)
text_fixture.write(sys.argv[2], "skyfieldStarPlaces", "Scripts/Fixtures/star-fixtures.py", "star julianDate astrometric.x astrometric.y astrometric.z lightTime apparent.x apparent.y apparent.z", sky_places)
