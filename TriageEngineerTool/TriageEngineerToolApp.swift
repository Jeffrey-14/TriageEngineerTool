//
//  TriageEngineerToolApp.swift
//  TriageEngineerTool
//
//  Created by Nana Yaw on 7/14/25.
//

import SwiftUI
import Charts

// MARK: - Bug Model
struct Bug: Identifiable, Decodable {
    let id: Int
    let type: String // e.g., "crash", "ui", "performance"
    let app: String // e.g., "Messages", "Safari"
    let severity: String // e.g., "critical", "medium", "low"
    let title: String // e.g., "Null pointer on send"
    let resolution: String?
}

// MARK: - ViewModel
class BugDashboardViewModel: ObservableObject {
    @Published var bugs: [Bug] = []
    private let filePath = "/Users/nanayaw/Desktop/TriageEngineerTools/bug_reports.json"
    
    func bugCounts(forApp app: String = "") -> [(type: String, count: Int)] {
        let filteredBugs = app.isEmpty ? bugs : bugs.filter { $0.app == app }
        let counts = Dictionary(grouping: filteredBugs, by: { $0.type })
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.type < $1.type }
        print("Bug counts for \(app.isEmpty ? "All" : app): \(counts)")
        return counts
    }
    
    func filterBugs(byApp app: String) -> [Bug] {
        bugs.filter { app == "All" || $0.app == app }
    }
    
    func assignTeam(forBug bug: Bug) -> String {
        switch bug.app {
        case "Messages": return "Messages Team"
        case "Safari": return "Safari Team"
        case "FaceTime": return "FaceTime Team"
        case "Mail": return "Mail Team"
        default: return "General Team"
        }
    }
    
    func fetchBugsFromFile() async throws {
        print("Fetching bugs from JSON at \(filePath)...")
        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)
        let bugs = try JSONDecoder().decode([Bug].self, from: data)
        print("Fetched \(bugs.count) bugs from JSON")
        await MainActor.run {
            self.bugs = bugs
        }
    }
}

// MARK: - Bug Dashboard View
struct BugDashboardView: View {
    @StateObject private var viewModel = BugDashboardViewModel()
    @State private var selectedApp = "All"
    private let apps = ["All", "Messages", "Safari", "FaceTime", "Mail"]
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Radar Bug Triage")
                    .font(.title)
                    .padding()
                
                // App Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(apps, id: \.self) { app in
                            Text(app)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .opacity(selectedApp == app ? 1.0 : 0.5)
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedApp = app
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Dashboard Content
                if viewModel.bugs.isEmpty {
                    Text("No bugs available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Chart(viewModel.bugCounts(forApp: selectedApp), id: \.type) { item in
                        BarMark(
                            x: .value("Type", item.type),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(by: .value("Type", item.type))
                    }
                    .chartForegroundStyleScale([
                        "crash": .red,
                        "ui": .blue,
                        "performance": .green
                    ])
                    .frame(height: 200)
                    .padding()
                    
                    List(viewModel.filterBugs(byApp: selectedApp)) { bug in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(bug.title)
                                    .font(.headline)
                                Text("Severity: \(bug.severity)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(viewModel.assignTeam(forBug: bug))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer()
            }
            .navigationTitle("Triage Dashboard")
            .task {
                do {
                    try await viewModel.fetchBugsFromFile()
                } catch {
                    print("Error fetching bugs: \(error)")
                }
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct TriageDemoApp: App {
    var body: some Scene {
        WindowGroup {
            BugDashboardView()
        }
    }
}
