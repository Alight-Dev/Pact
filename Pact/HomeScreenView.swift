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
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Daily\nActivities")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.black)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.top, 64)
                        .padding(.bottom, 36)

                    if activities.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(white: 0.75))
                            Text("No activities yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5))
                            Text("Add your first daily activity below")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.65))
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivitySheet { name, description, iconName, repeatDays in
                let activity = Activity(
                    name: name,
                    activityDescription: description,
                    iconName: iconName,
                    order: activities.count,
                    repeatDays: repeatDays
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
                    .fill(Color(white: 0.90))
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
                .fill(Color(red: 0.96, green: 0.96, blue: 0.98))
        )
    }
}

// MARK: - AddActivitySheet

struct AddActivitySheet: View {
    var onSave: (String, String, String, [Int]) -> Void

    @State private var name = ""
    @State private var activityDescription = ""
    @State private var selectedIcon = "figure.run"
    @State private var selectedDays: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

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
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Navigation bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.6))

                    Spacer()

                    Text("New Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    Button("Save") {
                        if !trimmedName.isEmpty {
                            onSave(
                                trimmedName,
                                activityDescription.trimmingCharacters(in: .whitespaces),
                                selectedIcon,
                                selectedDays.sorted()
                            )
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(trimmedName.isEmpty ? Color(white: 0.75) : .black)
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
                                .foregroundStyle(Color(white: 0.55))
                                .kerning(0.6)

                            TextField("e.g. Morning Run", text: $name)
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .tint(.black)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.94))
                                )
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))
                                .kerning(0.6)

                            TextField("e.g. Run at least 3km", text: $activityDescription)
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .tint(.black)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.94))
                                )
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))
                                .kerning(0.6)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(selectedIcon == icon ? .white : Color(white: 0.45))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon ? Color.black : Color(white: 0.92))
                                            )
                                    }
                                }
                            }
                        }

                        // Repeat Days picker
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Repeat Days")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black)

                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { index in
                                    let isSelected = selectedDays.contains(index)
                                    Button {
                                        if isSelected {
                                            selectedDays.remove(index)
                                        } else {
                                            selectedDays.insert(index)
                                        }
                                    } label: {
                                        Text(dayLabels[index])
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white : Color(white: 0.55))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(isSelected ? Color.black : Color(white: 0.88))
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
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
