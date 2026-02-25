//
//  HomeScreenView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI
import SwiftData

// MARK: - HomeScreenView

struct HomeScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Activity.order), SortDescriptor(\Activity.createdAt)])
    private var activities: [Activity]

    @State private var showingAddActivity = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Daily\nActivities")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.top, 64)
                        .padding(.bottom, 36)

                    if activities.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(white: 0.3))
                            Text("No activities yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))
                            Text("Add your first daily activity below")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.38))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Activity list
                        VStack(spacing: 12) {
                            ForEach(activities) { activity in
                                ActivityRowView(activity: activity)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Bottom spacing for the fixed button
                    Spacer().frame(height: 120)
                }
            }

            // Add Activity button (fixed at bottom)
            Button {
                showingAddActivity = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add Activity")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivitySheet { name, description, iconName in
                let activity = Activity(
                    name: name,
                    activityDescription: description,
                    iconName: iconName,
                    order: activities.count
                )
                modelContext.insert(activity)
                showingAddActivity = false
            }
        }
    }
}

// MARK: - ActivityRowView

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                    .frame(width: 48, height: 48)
                Image(systemName: activity.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)

                if !activity.activityDescription.isEmpty {
                    Text(activity.activityDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.58))
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }
}

// MARK: - AddActivitySheet

struct AddActivitySheet: View {
    var onSave: (String, String, String) -> Void

    @State private var name = ""
    @State private var activityDescription = ""
    @State private var selectedIcon = "figure.run"
    @Environment(\.dismiss) private var dismiss

    private let icons = [
        "figure.run", "figure.walk", "figure.hiking",
        "dumbbell.fill", "bicycle", "figure.swimming",
        "book.fill", "pencil", "brain.head.profile",
        "fork.knife", "drop.fill", "moon.fill",
        "heart.fill", "flame.fill", "music.note",
        "camera.fill", "paintbrush.fill", "gamecontroller.fill",
        "briefcase.fill", "laptopcomputer", "chart.bar.fill",
        "bed.double.fill", "person.fill", "stopwatch.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Navigation bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.5))

                    Spacer()

                    Text("New Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button("Save") {
                        if !trimmedName.isEmpty {
                            onSave(trimmedName, activityDescription.trimmingCharacters(in: .whitespaces), selectedIcon)
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(trimmedName.isEmpty ? Color(white: 0.32) : .white)
                    .disabled(trimmedName.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.42))
                                .kerning(0.6)

                            TextField("e.g. Morning Run", text: $name)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .tint(.white)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.1))
                                )
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.42))
                                .kerning(0.6)

                            TextField("e.g. Run at least 3km", text: $activityDescription)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .tint(.white)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.1))
                                )
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.42))
                                .kerning(0.6)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(selectedIcon == icon ? .black : Color(white: 0.65))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon ? Color.white : Color(white: 0.12))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    HomeScreenView()
        .modelContainer(for: Activity.self, inMemory: true)
}
