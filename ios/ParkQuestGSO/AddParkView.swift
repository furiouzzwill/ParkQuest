//
//  AddParkView.swift
//  ParkQuestGSO
//
//  Multi-step wizard shown to City Partners for adding a new park and
//  its landmarks. Steps:
//    1. Details form (park name, type, address, website, description,
//       contact name / email / phone)
//    2. Landmarks — a map you tap to drop pins, with a sheet to name
//       each landmark and set its radius + reward points
//    3. Review + save — POST to Supabase parks + park_geofences
//
//  Called from CityAdminView (both the "Add New Park" management button
//  and the empty-state card that appears when a city has zero parks).
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Draft models

/// In-progress landmark before it's persisted. UUID is client-generated
/// so we can list/edit before saving.
private struct DraftLandmark: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var description: String
    var coordinate: CLLocationCoordinate2D
    var radiusMeters: Double
    var rewardPoints: Int

    static func == (lhs: DraftLandmark, rhs: DraftLandmark) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Wizard root

struct AddParkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettings.self) private var userSettings
    @Environment(LocationManager.self) private var location

    /// Fires after a successful save so the parent can refresh its list.
    let onSaved: () -> Void

    @State private var step: Int = 0

    // Details
    @State private var parkName: String     = ""
    @State private var parkType: PartnerParkType = .publicPark
    @State private var address: String      = ""
    @State private var website: String      = ""
    @State private var descriptionText: String = ""
    @State private var contactName: String  = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""

    // Landmarks
    @State private var landmarks: [DraftLandmark] = []
    @State private var editingLandmark: DraftLandmark?

    // Save state
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                Group {
                    switch step {
                    case 0: detailsStep
                    case 1: landmarksStep
                    default: reviewStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .sheet(item: $editingLandmark) { draft in
                LandmarkEditorSheet(
                    draft: draft,
                    onSave: { updated in
                        if let idx = landmarks.firstIndex(where: { $0.id == updated.id }) {
                            landmarks[idx] = updated
                        } else {
                            landmarks.append(updated)
                        }
                        editingLandmark = nil
                    },
                    onCancel: { editingLandmark = nil }
                )
            }
            .alert("Couldn't save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Step indicator

    private var stepTitle: String {
        switch step {
        case 0: return "Park details"
        case 1: return "Landmarks"
        default: return "Review"
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.primaryGreen : Theme.lockGray.opacity(0.5))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Step 1: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tell us about the park")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .padding(.top, 8)

                labeledField("Park name *", text: $parkName, placeholder: "e.g. Barber Park")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Park type *")
                        .font(.pqLabel)
                        .foregroundStyle(Theme.mutedText)
                    Menu {
                        ForEach(PartnerParkType.allCases, id: \.self) { type in
                            Button {
                                parkType = type
                            } label: {
                                Label(type.label, systemImage: type.symbol)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: parkType.symbol)
                                .foregroundStyle(Theme.primaryGreen)
                            Text(parkType.label)
                                .foregroundStyle(Theme.darkText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.mutedText)
                        }
                        .padding(14)
                        .background(.white, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lockGray.opacity(0.5), lineWidth: 1))
                    }
                }

                labeledField("Address *", text: $address, placeholder: "1500 Barber Park Dr, Greensboro, NC")
                labeledField("Website", text: $website, placeholder: "https://…", keyboard: .URL)
                labeledMultilineField("Brief description", text: $descriptionText, placeholder: "2–3 sentences about the park…")

                Text("Contact")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .padding(.top, 6)

                labeledField("Contact name *", text: $contactName, placeholder: "Jane Smith")
                labeledField("Contact email *", text: $contactEmail, placeholder: "jane@parks.gov", keyboard: .emailAddress)
                labeledField("Contact phone *", text: $contactPhone, placeholder: "(336) 555-0100", keyboard: .phonePad)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Step 2: Landmarks

    @State private var landmarkMapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.0521, longitude: -79.7519),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

    private var landmarksStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tap the map to add a landmark")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                Text("Explorers earn points for visiting each one. You can also add one at your current location.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            MapReader { proxy in
                Map(position: $landmarkMapPosition) {
                    UserAnnotation()
                    ForEach(landmarks) { l in
                        Annotation(l.name, coordinate: l.coordinate, anchor: .bottom) {
                            landmarkPin(index: landmarks.firstIndex(where: { $0.id == l.id }) ?? 0)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .frame(height: 280)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        Haptics.medium()
                        addLandmarkAtCurrentLocation()
                    } label: {
                        Label("Use my location", systemImage: "location.fill")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.primaryGreen, in: .capsule)
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    }
                    .padding(10)
                }
                .onTapGesture(coordinateSpace: .local) { location in
                    if let coord = proxy.convert(location, from: .local) {
                        Haptics.soft()
                        editingLandmark = DraftLandmark(
                            name: "",
                            description: "",
                            coordinate: coord,
                            radiusMeters: 50,
                            rewardPoints: 25
                        )
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if landmarks.isEmpty {
                        Text("No landmarks yet — tap on the map above to add your first one.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.mutedText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(Array(landmarks.enumerated()), id: \.element.id) { idx, l in
                            landmarkRow(index: idx, landmark: l)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // If we know where the user is, center on them the first time
            // this step appears so tapping the map is intuitive.
            if let loc = location.currentLocation {
                landmarkMapPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                ))
            }
        }
    }

    private func addLandmarkAtCurrentLocation() {
        guard let loc = location.currentLocation else {
            errorMessage = "Location not available yet. Try again in a moment, or tap the map to place manually."
            return
        }
        editingLandmark = DraftLandmark(
            name: "",
            description: "",
            coordinate: loc.coordinate,
            radiusMeters: 50,
            rewardPoints: 25
        )
    }

    private func landmarkPin(index: Int) -> some View {
        ZStack {
            Circle().fill(.white).frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Circle().fill(Theme.primaryGreen).frame(width: 24, height: 24)
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func landmarkRow(index: Int, landmark: DraftLandmark) -> some View {
        HStack(spacing: 12) {
            landmarkPin(index: index)
            VStack(alignment: .leading, spacing: 2) {
                Text(landmark.name.isEmpty ? "(Untitled)" : landmark.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                Text("\(Int(landmark.radiusMeters))m radius · +\(landmark.rewardPoints) pts")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mutedText)
            }
            Spacer()
            Button {
                Haptics.soft()
                editingLandmark = landmark
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.primaryGreen)
                    .padding(8)
                    .background(Theme.primaryGreen.opacity(0.12), in: .circle)
            }
            Button {
                Haptics.soft()
                landmarks.removeAll { $0.id == landmark.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.dailyRed)
                    .padding(8)
                    .background(Theme.dailyRed.opacity(0.12), in: .circle)
            }
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    // MARK: - Step 3: Review + Save

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ready to publish")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.darkText)
                    .padding(.top, 8)

                reviewCard(title: "Park", rows: [
                    ("Name",        parkName),
                    ("Type",        parkType.label),
                    ("Address",     address),
                    ("Website",     website.isEmpty ? "—" : website),
                    ("Description", descriptionText.isEmpty ? "—" : descriptionText)
                ])

                reviewCard(title: "Contact", rows: [
                    ("Name",  contactName),
                    ("Email", contactEmail),
                    ("Phone", contactPhone)
                ])

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Landmarks (\(landmarks.count))")
                    if landmarks.isEmpty {
                        Text("No landmarks added.")
                            .font(.pqLabel).foregroundStyle(Theme.mutedText)
                    } else {
                        ForEach(Array(landmarks.enumerated()), id: \.element.id) { idx, l in
                            HStack(spacing: 12) {
                                landmarkPin(index: idx)
                                Text(l.name.isEmpty ? "(Untitled)" : l.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.darkText)
                                Spacer()
                                Text("+\(l.rewardPoints) pts")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.amber)
                            }
                        }
                    }
                }
                .padding(14)
                .background(.white, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func reviewCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.mutedText)
                        .frame(width: 84, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.darkText)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Theme.mutedText)
    }

    // MARK: - Footer buttons

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    Haptics.soft()
                    withAnimation { step -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.lockGray.opacity(0.6), lineWidth: 1))
                }
            }
            Button {
                Haptics.medium()
                nextTapped()
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == 2 ? "Publish park" : "Continue")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(canAdvance ? Theme.primaryGreen : Theme.lockGray, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }
            .disabled(!canAdvance || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.white.opacity(0.95))
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            return !parkName.trimmingCharacters(in: .whitespaces).isEmpty
                && !address.trimmingCharacters(in: .whitespaces).isEmpty
                && !contactName.trimmingCharacters(in: .whitespaces).isEmpty
                && contactEmail.contains("@") && contactEmail.contains(".")
                && !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            // Landmarks are optional; they can add more later.
            return true
        default:
            return true
        }
    }

    private func nextTapped() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            savePark()
        }
    }

    private func savePark() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let parkID = try await SupabaseService.shared.createPark(
                    cityID:       userSettings.cityID.isEmpty ? nil : userSettings.cityID,
                    parkName:     parkName.trimmingCharacters(in: .whitespaces),
                    parkType:     parkType.rawValue,
                    address:      address.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    website:      website.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    description:  descriptionText.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    contactName:  contactName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    contactEmail: contactEmail.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    contactPhone: contactPhone.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                    adminUserID:  userSettings.userID
                )
                for l in landmarks {
                    try await SupabaseService.shared.createLandmark(
                        parkID: parkID,
                        name: l.name.trimmingCharacters(in: .whitespaces),
                        description: l.description.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                        latitude: l.coordinate.latitude,
                        longitude: l.coordinate.longitude,
                        radiusMeters: l.radiusMeters,
                        rewardPoints: l.rewardPoints
                    )
                }
                await MainActor.run {
                    Haptics.success()
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Shared field builders

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.pqLabel).foregroundStyle(Theme.mutedText)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled(keyboard != .default)
                .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .sentences)
                .padding(14)
                .background(.white, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lockGray.opacity(0.5), lineWidth: 1))
        }
    }

    private func labeledMultilineField(
        _ label: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.pqLabel).foregroundStyle(Theme.mutedText)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(Theme.mutedText.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                }
                TextEditor(text: text)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
            }
            .background(.white, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lockGray.opacity(0.5), lineWidth: 1))
        }
    }
}

// MARK: - Landmark editor sheet

private struct LandmarkEditorSheet: View {
    let draft: DraftLandmark
    let onSave: (DraftLandmark) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var radius: Double
    @State private var points: Double

    init(draft: DraftLandmark,
         onSave: @escaping (DraftLandmark) -> Void,
         onCancel: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
        _name        = State(initialValue: draft.name)
        _description = State(initialValue: draft.description)
        _radius      = State(initialValue: draft.radiusMeters)
        _points      = State(initialValue: Double(draft.rewardPoints))
    }

    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Map(position: $mapPosition, interactionModes: []) {
                        Annotation("", coordinate: draft.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle().fill(.white).frame(width: 34, height: 34)
                                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                                Circle().fill(Theme.primaryGreen).frame(width: 26, height: 26)
                                Image(systemName: "mappin")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                        }
                        MapCircle(center: draft.coordinate, radius: radius)
                            .foregroundStyle(Theme.primaryGreen.opacity(0.18))
                            .stroke(Theme.primaryGreen.opacity(0.6), lineWidth: 1.5)
                    }
                    .mapStyle(.hybrid(elevation: .realistic))
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name *").font(.pqLabel).foregroundStyle(Theme.mutedText)
                        TextField("e.g. Main Playground", text: $name)
                            .padding(14)
                            .background(.white, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lockGray.opacity(0.5), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.pqLabel).foregroundStyle(Theme.mutedText)
                        TextField("What's here? What should explorers look for?", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(.white, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lockGray.opacity(0.5), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Check-in radius").font(.pqLabel).foregroundStyle(Theme.mutedText)
                            Spacer()
                            Text("\(Int(radius)) m")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.darkText)
                        }
                        Slider(value: $radius, in: 20...200, step: 5)
                            .tint(Theme.primaryGreen)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Reward points").font(.pqLabel).foregroundStyle(Theme.mutedText)
                            Spacer()
                            Text("+\(Int(points))")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.amber)
                        }
                        Slider(value: $points, in: 5...100, step: 5)
                            .tint(Theme.amber)
                    }
                }
                .padding(20)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Landmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.mutedText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = draft
                        updated.name = name
                        updated.description = description
                        updated.radiusMeters = radius
                        updated.rewardPoints = Int(points)
                        onSave(updated)
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.mutedText : Theme.primaryGreen)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                mapPosition = .region(MKCoordinateRegion(
                    center: draft.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                ))
            }
        }
    }
}

// MARK: - Helpers

private extension String {
    /// Return nil if the string is empty after trimming — useful for
    /// optional Supabase columns so we don't insert "" instead of NULL.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
