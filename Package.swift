// swift-tools-version: 5.9
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
	dependencies: [
		.package(url: "https://github.com/sbooth/CAstronomyEngine.git", branch: "main")
	],
	targets: [
		.target(
			name: "Astronomia",
			dependencies: [
				"CAstronomyEngine",
			]
		),
		.testTarget(
			name: "AstronomiaTests",
			dependencies: [
				"Astronomia",
			]
		),
	]
)
