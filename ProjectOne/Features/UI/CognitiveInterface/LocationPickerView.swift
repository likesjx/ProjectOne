//
//  LocationPickerView.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Interactive map-based location picker for memory target locations
//

import SwiftUI
import MapKit
import CoreLocation

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct LocationPickerView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    // Location selection callback
    let onLocationSelected: (CLLocationCoordinate2D, String?) -> Void
    
    // Map region and selected location
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName: String?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    
    // Location manager for current location
    @StateObject private var locationManager = LocationPickerLocationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Map view
                mapSection
                
                // Selected location info
                if let coordinate = selectedCoordinate {
                    selectedLocationSection(coordinate: coordinate)
                }
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Select Target Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Use Current Location") {
                        useCurrentLocation()
                    }
                    .disabled(!locationManager.hasLocationPermission)
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty {
                performSearch()
            } else {
                searchResults = []
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchSection: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for places...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // Search results
            if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(searchResults, id: \.self) { item in
                            SearchResultRow(item: item) {
                                selectSearchResult(item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 120)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemGray6))
    }
    
    private var mapSection: some View {
        Map(coordinateRegion: $region, annotationItems: selectedCoordinate.map { [LocationAnnotation(coordinate: $0)] } ?? []) { annotation in
            MapPin(coordinate: annotation.coordinate, tint: .red)
        }
        .onTapGesture { location in
            let coordinate = region.center
            selectCoordinate(coordinate, fromSearch: false)
        }
        .gesture(
            DragGesture()
                .onEnded { _ in
                    // When user stops dragging, use the center of the map as selected location
                    selectCoordinate(region.center, fromSearch: false)
                }
        )
        .overlay(
            // Crosshair overlay to show center point
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.red)
                .background(Color.white.clipShape(Circle()))
                .allowsHitTesting(false),
            alignment: .center
        )
    }
    
    private func selectedLocationSection(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let name = selectedLocationName {
                        Text(name)
                            .font(.headline)
                    }
                    
                    Text("\(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Select location button
            Button(action: confirmSelection) {
                Text("Select This Location")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCoordinate != nil ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(selectedCoordinate == nil)
            
            // Clear selection button
            if selectedCoordinate != nil {
                Button(action: clearSelection) {
                    Text("Clear Selection")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    searchResults = response.mapItems
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let name = item.name ?? item.placemark.title
        
        selectCoordinate(coordinate, name: name, fromSearch: true)
        
        // Update map region to show selected location
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // Clear search
        searchText = ""
        searchResults = []
    }
    
    private func selectCoordinate(_ coordinate: CLLocationCoordinate2D, name: String? = nil, fromSearch: Bool) {
        selectedCoordinate = coordinate
        
        if fromSearch {
            selectedLocationName = name
        } else {
            // Reverse geocode to get location name
            reverseGeocode(coordinate: coordinate)
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    selectedLocationName = placemark.name ?? placemark.thoroughfare ?? "Selected Location"
                } else {
                    selectedLocationName = "Selected Location"
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        guard let currentLocation = locationManager.lastLocation else { return }
        
        let coordinate = currentLocation.coordinate
        selectCoordinate(coordinate, name: "Current Location", fromSearch: false)
        
        // Update map region to show current location
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    private func confirmSelection() {
        guard let coordinate = selectedCoordinate else { return }
        onLocationSelected(coordinate, selectedLocationName)
        dismiss()
    }
    
    private func clearSelection() {
        selectedCoordinate = nil
        selectedLocationName = nil
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct SearchResultRow: View {
    let item: MKMapItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown Location")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let address = formatAddress(placemark: item.placemark) {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatAddress(placemark: CLPlacemark) -> String? {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - Location Manager

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private class LocationPickerLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    @Published var lastLocation: CLLocation?
    @Published var hasLocationPermission = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationPermission()
    }
    
    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    private func checkLocationPermission() {
        hasLocationPermission = locationManager.authorizationStatus == .authorizedWhenInUse ||
                               locationManager.authorizationStatus == .authorizedAlways
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location error silently
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationPermission()
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerView { coordinate, name in
            print("Selected: \(coordinate), \(name ?? "No name")")
        }
    }
}