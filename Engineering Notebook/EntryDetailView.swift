//
//  EntryDetailView.swift
//  Engineering Notebook
//
//  Read-only detail for a previously submitted observation.
//

import SwiftUI

struct EntryDetailView: View {
    let entry: Entry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let data = entry.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.body)
                }

                if let location = entry.location {
                    section("Location") {
                        LocationMap(location: location)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let placeName = location.placeName {
                            Text(placeName).font(.subheadline)
                        }
                        Text(String(format: "%.5f, %.5f", location.latitude, location.longitude))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasData {
                    section("Data") {
                        if let temperature = entry.temperature {
                            dataRow("Temperature",
                                    value: "\(formatted(temperature)) \(entry.temperatureUnit.rawValue)")
                        }
                        if let measurement = entry.measurement {
                            dataRow("Measurement",
                                    value: "\(formatted(measurement))\(entry.measurementUnit.map { " \($0)" } ?? "")")
                        }
                        if let rating = entry.rating {
                            HStack {
                                Text("Rating").foregroundStyle(.secondary)
                                Spacer()
                                RatingLabel(rating: rating)
                            }
                        }
                    }
                }

                section("Recorded") {
                    Text(entry.createdAt, format: .dateTime.weekday().month().day().year().hour().minute())
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .navigationTitle("Observation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasData: Bool {
        entry.temperature != nil || entry.measurement != nil || entry.rating != nil
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func dataRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
