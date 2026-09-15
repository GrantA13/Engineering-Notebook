//
//  Models.swift
//  Engineering Notebook
//
//  Domain models shared by the UI and the backend service layer.
//

import Foundation

/// An engineering project that groups together related field entries.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, summary: String = "", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.summary = summary
        self.createdAt = createdAt
    }
}

/// A geographic coordinate captured for an observation, with an optional
/// human-readable place name resolved via reverse geocoding.
struct GeoLocation: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var placeName: String?
}

/// The temperature scale an observation's temperature reading was recorded in.
enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius = "°C"
    case fahrenheit = "°F"

    var id: String { rawValue }
}

/// A single note or observation belonging to a `Project`.
///
/// Everything beyond the note text and timestamp is optional so field workers
/// can capture as much or as little structured data as a situation allows.
struct Entry: Identifiable, Codable, Hashable {
    let id: UUID
    var projectID: UUID
    var note: String
    var location: GeoLocation?

    /// JPEG image data. Encoded as base64 when sent to the backend as JSON.
    var photoData: Data?

    // Optional structured data.
    var temperature: Double?
    var temperatureUnit: TemperatureUnit
    var measurement: Double?
    var measurementUnit: String?
    /// A 1...5 rating, or `nil` if not rated.
    var rating: Int?

    var createdAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        note: String,
        location: GeoLocation? = nil,
        photoData: Data? = nil,
        temperature: Double? = nil,
        temperatureUnit: TemperatureUnit = .celsius,
        measurement: Double? = nil,
        measurementUnit: String? = nil,
        rating: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.note = note
        self.location = location
        self.photoData = photoData
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.measurement = measurement
        self.measurementUnit = measurementUnit
        self.rating = rating
        self.createdAt = createdAt
    }
}
