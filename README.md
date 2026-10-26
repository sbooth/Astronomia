# Astronomia

Astronomy calculations in Swift: precise time, positions of the Sun, Moon, planets
and stars, and events including rises, sets, and eclipses.

## Features

- **Time**
  - Julian dates, and Julian, Gregorian, and combined calendars.
  - The timescales UTC (with leap seconds), TAI, TT, TDB, TCB, TCG, and UT1, and the GNSS
    timescales.
  - ΔT from observations, models, and extrapolation.
- **Earth orientation**
  - IAU 2006/2000A precession and nutation, and sidereal time.
  - The celestial, intermediate, and terrestrial frames.
  - Polar motion and IERS Earth orientation data.
- **Ephemerides**
  - A built-in ephemeris of the Sun, the Moon, and the planets from J1000.0 to J3000.0, from
    the solutions VSOP2013 and ELP/MPP02.
  - A choice of precision, trading accuracy for speed.
  - Protocols for supplying your own ephemeris.
- **Positions**
  - Astrometric, apparent, and observed places of bodies and stars, with light time,
    gravitational deflection, aberration, and refraction.
  - Stars from their catalog astrometry, and a built-in catalog of the stars named by the IAU.
  - Illumination, phase angle, and semidiameter.
- **Events**
  - Rises, sets, transits, and twilights.
  - The Moon's phases, apsides, nodes, and greatest declinations, and the seasons.
  - Eclipses of the Moon and the Sun, worldwide and as seen from a site.

The results are tested against ERFA, Skyfield with JPL's DE421, and NASA's eclipse catalogs.

## Example

```swift
import Astronomia

let now = try Instant<UTC>.now
let greenwich = try Observer.site(latitude: .degrees(51.4769), longitude: .degrees(-0.0005))

// Where Mars is in Greenwich's sky
let sky = try greenwich.observation(at: now)
let mars = try sky.observedPlace(of: sky.apparentPlace(of: .mars))
print(mars.altitude.degrees, mars.azimuth.degrees)

// The next sunrise, full Moon, and solar eclipse
let sunrise = try greenwich.nextRiseTransitSetEvent(.rise, of: .sun, after: now)
let fullMoon = try Moon.nextPhase(.fullMoon, after: now)
let eclipse = try Sun.nextEclipse(after: now)

// The June solstice of 2027
let solstice = try Seasons.instant(of: .juneSolstice, year: 2027)

// A named star
if let vega = NamedStar.named("Vega") {
	let place = try sky.observedPlace(of: sky.apparentPlace(of: vega.star))
}
```

## Installation

### Swift Package Manager

Add a package dependency to https://github.com/sbooth/Astronomia in Xcode.

### Manual or Custom Build

1. Clone the [Astronomia](https://github.com/sbooth/Astronomia) repository.
2. `swift build`.

## License

Astronomia is released under the [MIT License](https://github.com/sbooth/Astronomia/blob/main/LICENSE.txt).
