//
//  ParkMapCanvas.swift
//  ParkQuestGSO
//
//  Real MapKit map of Barber Park — satellite/hybrid imagery.
//  Replaces the previous SwiftUI Canvas illustration.
//

import SwiftUI
import MapKit

// MARK: - Shared region

extension MKCoordinateRegion {
    /// The default camera region that frames all of Barber Park.
    static let barberPark = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.0521, longitude: -79.7519),
        span: MKCoordinateSpan(latitudeDelta: 0.010, longitudeDelta: 0.012)
    )
}

// MARK: - Reusable map thumbnail (non-interactive)

/// Drop-in replacement for the old ParkMapCanvas.
/// Used in HomeView as a non-interactive card thumbnail.
struct ParkMapCanvas: View {
    var body: some View {
        Map(
            initialPosition: .region(.barberPark),
            interactionModes: []          // locked — no pan/zoom
        )
        .mapStyle(.hybrid(
            elevation: .realistic,
            pointsOfInterest: .excludingAll
        ))
        .disabled(true)
    }
}

#Preview {
    ParkMapCanvas()
        .frame(height: 300)
        .clipShape(.rect(cornerRadius: 20))
        .padding()
}
