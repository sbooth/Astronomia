// swift-tools-version: 6.0
//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import PackageDescription

let package = Package(
	name: "Astronomia",
	products: [
		.library(
			name: "Astronomia",
			targets: [
				"Astronomia",
			]),
	],
	targets: [
		.target(
			name: "Astronomia",
			dependencies: [
				"CAstronomiaData",
				"CAstronomiaPlatform",
			],
			linkerSettings: [
				.linkedFramework(
					"CoreLocation", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])
				),
			]
		),
		.target(
			name: "CAstronomiaData",
			dependencies: [
				"CAstronomiaPlatform",
			]
		),
		.target(
			name: "CAstronomiaPlatform",
			linkerSettings: [
				.linkedFramework(
					"Accelerate", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])
				),
			]
		),
		.testTarget(
			name: "AstronomiaTests",
			dependencies: [
				"Astronomia",
			],
			resources: [
				.copy("Fixtures"),
			]
		),
	]
)
