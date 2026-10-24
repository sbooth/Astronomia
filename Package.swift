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
				"CAstronomiaMath",
				"CAstronomiaData",
			]
		),
		.target(
			name: "CAstronomiaData",
			dependencies: [
				"CAstronomiaMath",
			],
			linkerSettings: [
				.linkedFramework(
					"Accelerate", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])
				)
			]
		),
		.target(
			name: "CAstronomiaMath"
		),
		.testTarget(
			name: "AstronomiaTests",
			dependencies: [
				"Astronomia",
			]
		),
	]
)
