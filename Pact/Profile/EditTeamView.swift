//
//  EditTeamView.swift
//  Pact
//

import SwiftUI

// MARK: - EditTeamView

struct EditTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var showingAddActivity = false
    @State private var activityToEdit: TeamActivity? = nil
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var allowAIFallback: Bool = true
    @State private var minApprovers: Int = 0

    private var teamId: String? { firestoreService.currentTeamId }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                List {
                    if firestoreService.teamActivities.isEmpty {
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
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(firestoreService.teamActivities) { activity in
                            Button {
                                activityToEdit = activity
                            } label: {
                                TeamActivityRowView(activity: activity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            // Swipe right → Delete
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteActivity(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            // Swipe left → Edit
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    activityToEdit = activity
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .foregroundStyle(.black)
                                }
                                .tint(Color(white: 0.55))
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        }
                    }

                    // MARK: Initial Conditions card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("INITIAL CONDITIONS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.55))
                            .kerning(0.6)
                            .padding(.bottom, 14)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Allow AI fallback")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                Text("Auto-verifies after ~2–3 hrs of peer inactivity")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.55))
                            }
                            Spacer()
                            Toggle("", isOn: $allowAIFallback)
                                .labelsHidden()
                                .tint(.black)
                        }
                        .padding(.bottom, 16)

                        Divider()
                            .padding(.bottom, 14)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Minimum required approvers")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                            ApproverSegmentedPicker(selection: $minApprovers)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))

                    // Bottom padding so last card isn't hidden behind button
                    Color.clear
                        .frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                VStack(spacing: 0) {
                    if let error = saveError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                    }

                    Button {
                        showingAddActivity = true
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Add Activity")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSaving ? Color(white: 0.6) : Color.black)
                        )
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .navigationTitle("Edit Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        .presentationDragIndicator(.visible)
        // Add sheet
        .sheet(isPresented: $showingAddActivity) {
            AddActivitySheet { name, description, iconName, repeatDays, isOptional in
                addActivity(name: name, description: description,
                            iconName: iconName, repeatDays: repeatDays, isOptional: isOptional)
                showingAddActivity = false
            }
        }
        // Edit sheet — pre-filled with TeamActivity values
        .sheet(item: $activityToEdit) { activity in
            AddActivitySheet(
                name: activity.name,
                description: activity.activityDescription,
                iconName: activity.iconName,
                repeatDays: activity.repeatDays,
                isOptional: activity.isOptional
            ) { name, description, iconName, repeatDays, isOptional in
                updateActivity(activity, name: name, description: description,
                               iconName: iconName, repeatDays: repeatDays, isOptional: isOptional)
                activityToEdit = nil
            }
        }
    }

    // MARK: - Firestore Operations

    private func addActivity(name: String, description: String, iconName: String,
                             repeatDays: [Int], isOptional: Bool) {
        guard let teamId else { return }
        let order = firestoreService.teamActivities.count
        let payload = ActivityPayload(name: name, description: description, iconName: iconName,
                                     repeatDays: repeatDays, isOptional: isOptional, order: order)
        isSaving = true
        saveError = nil
        Task {
            do {
                try await firestoreService.addGoal(teamId: teamId, payload: payload)
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func updateActivity(_ activity: TeamActivity, name: String, description: String,
                                iconName: String, repeatDays: [Int], isOptional: Bool) {
        guard let teamId else { return }
        let payload = ActivityPayload(name: name, description: description, iconName: iconName,
                                     repeatDays: repeatDays, isOptional: isOptional, order: activity.order)
        isSaving = true
        saveError = nil
        Task {
            do {
                try await firestoreService.updateGoal(teamId: teamId, goalId: activity.id, payload: payload)
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func deleteActivity(_ activity: TeamActivity) {
        guard let teamId else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await firestoreService.deleteGoal(teamId: teamId, goalId: activity.id)
            } catch {
                saveError = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - TeamActivityRowView

private struct TeamActivityRowView: View {
    let activity: TeamActivity

    private var daysText: String? {
        let count = activity.repeatDays.count
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? "Day" : "Days")"
    }

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
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
                if activity.isOptional {
                    Text("Optional")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.88))
                        )
                }
                if let text = daysText {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Preview

#Preview {
    EditTeamView()
        .environmentObject(FirestoreService())
}
