//
//  SharedViews.swift
//  Engineering Notebook
//
//  Small reusable UI components.
//

import SwiftUI
import MapKit

/// An interactive 1...5 star rating control.
struct RatingPicker: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .imageScale(.large)
                    .onTapGesture {
                        // Tapping the current rating again clears it.
                        rating = (rating == star) ? nil : star
                    }
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
            if rating != nil {
                Button("Clear") { rating = nil }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// A compact, read-only star display.
struct RatingLabel: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: rating >= star ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .imageScale(.small)
            }
        }
    }
}

/// A non-interactive map snapshot centered on a coordinate.
struct LocationMap: View {
    let location: GeoLocation

    var body: some View {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )) {
            Marker(location.placeName ?? "Observation", coordinate: coordinate)
        }
        .disabled(true)
    }
}
