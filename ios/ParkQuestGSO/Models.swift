//
//  Models.swift
//  ParkQuestGSO
//

import SwiftUI
import CoreLocation

// MARK: - User Types

/// Defines the two roles in ParkQuest.
/// - explorer: end user exploring parks in their city
/// - cityAdmin: city-level account that manages parks and branding for a deployed city instance
enum UserType: String, CaseIterable, Codable {
    case explorer  = "explorer"
    case cityAdmin = "city_admin"

    var label: String {
        switch self {
        case .explorer:  return "Park Explorer"
        case .cityAdmin: return "City Admin"
        }
    }

    var symbol: String {
        switch self {
        case .explorer:  return "figure.walk"
        case .cityAdmin: return "building.2.fill"
        }
    }
}

// MARK: - City

/// A city deployment of ParkQuest. Cities are the top-level account tier;
/// each city owns a set of parks that explorers discover within it.
struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let state: String
    let parks: [Park]

    var displayName: String { "\(name), \(state)" }
}

// MARK: - Quest Kinds

enum QuestKind {
    case landmark
    case facility
    case recreation
    case venue
    case nature
    case daily

    var label: String {
        switch self {
        case .landmark: return "Nature Landmark"
        case .facility: return "Park Facility"
        case .recreation: return "Recreation"
        case .venue: return "Venue"
        case .nature: return "Nature"
        case .daily: return "Bonus Challenge"
        }
    }

    var symbol: String {
        switch self {
        case .landmark: return "tree.fill"
        case .facility: return "house.fill"
        case .recreation: return "figure.play"
        case .venue: return "music.mic"
        case .nature: return "drop.fill"
        case .daily: return "bolt.fill"
        }
    }
}

struct Quest: Identifiable {
    let id: String
    let name: String
    let kind: QuestKind
    let points: Int
    let description: String
    /// Position on the park map as fraction of width/height (0...1).
    let mapPosition: CGPoint
    /// Real-world GPS coordinate for proximity check-in verification.
    let coordinate: CLLocationCoordinate2D
}

// Quest equality and hashing are based solely on id.
extension Quest: Hashable {
    static func == (lhs: Quest, rhs: Quest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Park: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let badgeName: String
    let badgeSymbol: String
    let quests: [Quest]
    let isLocked: Bool
}

// MARK: - Seed data

enum SeedData {
    // -------------------------------------------------------------------------
    // Barber Park — Greensboro, NC
    // GPS coordinates are approximate field positions.
    // Verify / fine-tune with on-site measurement before shipping.
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Barber Park — 1500 Barber Park Dr, Greensboro, NC 27401
    //
    // GPS sources:
    //   • Playground, shelters, pool: OpenStreetMap confirmed
    //   • Park center: OSM / Nominatim
    //   • Amphitheater (1502 Barber Park Dr): estimated from park geometry
    //   • Oak Grove (east entrance): estimated from park geometry
    //
    // Fine-tune the estimated coords with on-site measurement before shipping.
    // -------------------------------------------------------------------------
    static let barberPark = Park(
        id: "barber",
        name: "Barber Park",
        city: "Greensboro, NC",
        badgeName: "Barber Park Explorer",
        badgeSymbol: "tree.fill",
        quests: [
            Quest(
                id: "oak",
                name: "The Oak Grove",
                kind: .landmark,
                points: 25,
                description: "Find the cluster of white oak trees near the east entrance. These oaks are over 80 years old and were here long before the park was built.",
                mapPosition: CGPoint(x: 0.22, y: 0.28),
                // East side of park near entrance road — estimated
                coordinate: CLLocationCoordinate2D(latitude: 36.0542, longitude: -79.7500)
            ),
            Quest(
                id: "pavilion",
                name: "Main Pavilion",
                kind: .facility,
                points: 25,
                description: "Check in at the park's main covered shelter. A perfect spot for a family picnic — see if anyone's already set up for the day.",
                mapPosition: CGPoint(x: 0.49, y: 0.46),
                // Shelter 4 (central picnic area) — OSM confirmed
                coordinate: CLLocationCoordinate2D(latitude: 36.0538, longitude: -79.7524)
            ),
            Quest(
                id: "playground",
                name: "Nature Playground",
                kind: .recreation,
                points: 25,
                description: "Find the main playground structure. Yes, adults can climb it too. No judgment here.",
                mapPosition: CGPoint(x: 0.36, y: 0.72),
                // OSM confirmed (way 569790043)
                coordinate: CLLocationCoordinate2D(latitude: 36.0537, longitude: -79.7519)
            ),
            Quest(
                id: "amphitheater",
                name: "The Amphitheater",
                kind: .venue,
                points: 25,
                description: "Locate the Yvonne J. Johnson Event Center & Amphitheater at 1502 Barber Park Dr. Greensboro hosts concerts and events here throughout the year.",
                mapPosition: CGPoint(x: 0.78, y: 0.22),
                // 1502 Barber Park Dr — estimated from park geometry
                coordinate: CLLocationCoordinate2D(latitude: 36.0517, longitude: -79.7528)
            ),
            Quest(
                id: "pond",
                name: "Reflection Pond",
                kind: .nature,
                points: 25,
                description: "Find the pond along the walking trail. Bring bread for the ducks — or don't, we're not your parents.",
                mapPosition: CGPoint(x: 0.74, y: 0.55),
                // Intermittent pond on east side — OSM confirmed (way 569793919)
                coordinate: CLLocationCoordinate2D(latitude: 36.0545, longitude: -79.7451)
            ),
            Quest(
                id: "daily",
                name: "Daily Challenge",
                kind: .daily,
                points: 50,
                description: "Visit all 5 locations in a single session to complete the Barber Park full sweep. Time to earn that badge.",
                mapPosition: CGPoint(x: 0.62, y: 0.84),
                // Park center — OSM confirmed
                coordinate: CLLocationCoordinate2D(latitude: 36.0521, longitude: -79.7519)
            )
        ],
        isLocked: false
    )

    static let lockedParks: [Park] = [
        Park(id: "country", name: "Country Park", city: "Greensboro, NC",
             badgeName: "Country Park Explorer", badgeSymbol: "leaf.fill",
             quests: [], isLocked: true),
        Park(id: "guilford", name: "Guilford Courthouse", city: "National Military Park",
             badgeName: "Guilford Explorer", badgeSymbol: "flag.fill",
             quests: [], isLocked: true)
    ]

    // -------------------------------------------------------------------------
    // City: Greensboro, NC (GSO) — first deployed city instance
    // Additional cities (Raleigh, Charlotte, etc.) follow the same structure.
    // -------------------------------------------------------------------------
    static let greensboro = City(
        id: "gso",
        name: "Greensboro",
        state: "NC",
        parks: [barberPark] + lockedParks
    )

    /// All city instances available in this build.
    static let allCities: [City] = [greensboro]
}
