//
//  EntryEditorView.swift
//  Engineering Notebook
//
//  Form for capturing a new observation: note, photo, location, and optional
//  structured data (temperature, measurement, rating).
//

import SwiftUI
import PhotosUI
import CoreLocation

struct EntryEditorView: View {
    let projectID: UUID

    @Environment(NotebookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var location = LocationProvider()

    // Core fields
    @State private var note = ""
    @State private var photoData: Data?
    @State private var geoLocation: GeoLocation?

    // Optional structured data
    @State private var temperatureText = ""
    @State private var temperatureUnit: TemperatureUnit = .celsius
    @State private var measurementText = ""
    @State private var measurementUnit = ""
    @State private var rating: Int?

    // UI state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isCapturingLocation = false
    @State private var locationError: String?
    @State private var isSaving = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Form {
                noteSection
                photoSection
                locationSection
                dataSection
            }
            .navigationTitle("New Observation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || !canSave)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    isShowingCamera = false
                    if let image { photoData = image.jpegDataForUpload() }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    // MARK: Sections

    private var noteSection: some View {
        Section("Note / Observation") {
            TextField("Describe what you observed…", text: $note, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Remove Photo", role: .destructive) {
                    self.photoData = nil
                    selectedPhotoItem = nil
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(photoData == nil ? "Upload from Library" : "Choose Different Photo",
                      systemImage: "photo.on.rectangle")
            }

            if cameraAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Location") {
            if let geoLocation {
                LocationMap(location: geoLocation)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())

                if let placeName = geoLocation.placeName {
                    Text(placeName).font(.subheadline)
                }
                Text(String(format: "%.5f, %.5f", geoLocation.latitude, geoLocation.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Remove Location", role: .destructive) {
                    self.geoLocation = nil
                }
            } else {
                Button {
                    captureLocation()
                } label: {
                    if isCapturingLocation {
                        HStack { ProgressView(); Text("Getting location…") }
                    } else {
                        Label("Record Current Location", systemImage: "location")
                    }
                }
                .disabled(isCapturingLocation)

                if let locationError {
                    Text(locationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data (optional)") {
            // Temperature
            HStack {
                TextField("Temperature", text: $temperatureText)
                    .keyboardType(.numbersAndPunctuation)
                Picker("Unit", selection: $temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            // Measurement
            HStack {
                TextField("Measurement", text: $measurementText)
                    .keyboardType(.decimalPad)
                TextField("Unit (e.g. mm)", text: $measurementUnit)
                    .frame(width: 110)
                    .multilineTextAlignment(.trailing)
            }

            // Rating
            HStack {
                Text("Rating")
                Spacer()
                RatingPicker(rating: $rating)
            }
        }
    }

    // MARK: Actions

    /// A note, photo, location, or any data field is enough to save.
    private var canSave: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || photoData != nil
            || geoLocation != nil
            || !temperatureText.isEmpty
            || !measurementText.isEmpty
            || rating != nil
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photoData = image.jpegDataForUpload()
            }
        }
    }

    private func captureLocation() {
        locationError = nil
        isCapturingLocation = true
        Task {
            defer { isCapturingLocation = false }
            do {
                let clLocation = try await location.requestCurrentLocation()
                let placeName = await location.placeName(for: clLocation)
                geoLocation = GeoLocation(
                    latitude: clLocation.coordinate.latitude,
                    longitude: clLocation.coordinate.longitude,
                    placeName: placeName
                )
            } catch {
                locationError = "Couldn't get location. Check location permissions in Settings."
            }
        }
    }

    private func save() {
        isSaving = true
        let entry = Entry(
            projectID: projectID,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: geoLocation,
            photoData: photoData,
            temperature: Double(temperatureText.replacingOccurrences(of: ",", with: ".")),
            temperatureUnit: temperatureUnit,
            measurement: Double(measurementText.replacingOccurrences(of: ",", with: ".")),
            measurementUnit: measurementUnit.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : measurementUnit.trimmingCharacters(in: .whitespaces),
            rating: rating
        )
        Task {
            let success = await store.addEntry(entry)
            isSaving = false
            if success { dismiss() }
        }
    }
}
