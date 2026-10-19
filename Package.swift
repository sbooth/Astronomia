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
				"AstronomiaData",
			]
		),
		.target(
			name: "AstronomiaData"
		),
		.testTarget(
			name: "AstronomiaTests",
			dependencies: [
				"Astronomia",
			]
		),
	]
)
