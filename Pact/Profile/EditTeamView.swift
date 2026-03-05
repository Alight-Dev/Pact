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
    @State private var activityToDelete: TeamActivity? = nil
    @State private var showDeleteWarning = false

    private var teamId: String? { firestoreService.currentTeamId }

    private func membersOptedIn(to activity: TeamActivity) -> [TeamMember] {
        firestoreService.members.filter { $0.optedInActivityIds.contains(activity.id) }
    }

    var body: some View {
        ZStack {
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
                            // Swipe right → Delete (with warning)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    activityToDelete = activity
                                    showDeleteWarning = true
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
            AddActivitySheet { name, description, iconName, repeatDays in
                addActivity(name: name, description: description,
                            iconName: iconName, repeatDays: repeatDays)
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
                onDelete: {
                    deleteActivity(activity)
                    activityToEdit = nil
                }
            ) { name, description, iconName, repeatDays in
                isSaving = true
                saveError = nil
                updateActivity(activity, name: name, description: description,
                               iconName: iconName, repeatDays: repeatDays) {
                    activityToEdit = nil
                }
            }
        }
        // Custom delete confirmation overlay
        if showDeleteWarning, let activity = activityToDelete {
            deleteConfirmationOverlay(for: activity)
        }
        } // outer ZStack
    }

    // MARK: - Delete Confirmation Overlay

    @ViewBuilder
    private func deleteConfirmationOverlay(for activity: TeamActivity) -> some View {
        let opted = membersOptedIn(to: activity)

        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    showDeleteWarning = false
                    activityToDelete = nil
                }
            }

        VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.96))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                }

                Text("Delete \(activity.name)?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)

                if opted.isEmpty {
                    Text("No one is currently opted in to this activity. This action cannot be undone.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                } else {
                    Text("The following members will be affected:")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.5))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        ForEach(opted) { member in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(white: 0.92))
                                        .frame(width: 36, height: 36)
                                    Text(memberInitial(member))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.black)
                                }

                                Text(member.nickname.isEmpty ? member.displayName : member.nickname)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(white: 0.96))
                            )
                        }
                    }

                    Text("This action cannot be undone.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showDeleteWarning = false
                        activityToDelete = nil
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(white: 0.96))
                        )
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        deleteActivity(activity)
                        showDeleteWarning = false
                        activityToDelete = nil
                    }
                } label: {
                    Text("Delete")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 32)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func memberInitial(_ member: TeamMember) -> String {
        let name = member.nickname.isEmpty ? member.displayName : member.nickname
        return String(name.prefix(1)).uppercased()
    }

    // MARK: - Firestore Operations

    private func addActivity(name: String, description: String, iconName: String,
                             repeatDays: [Int]) {
        guard let teamId else { return }
        let order = firestoreService.teamActivities.count
        let payload = ActivityPayload(name: name, description: description, iconName: iconName,
                                     repeatDays: repeatDays, order: order)
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
                                iconName: String, repeatDays: [Int], onSuccess: @escaping () -> Void = {}) {
        guard let teamId else { return }
        let payload = ActivityPayload(name: name, description: description, iconName: iconName,
                                     repeatDays: repeatDays, order: activity.order)
        Task {
            do {
                try await firestoreService.updateGoal(teamId: teamId, goalId: activity.id, payload: payload)
                await MainActor.run {
                    isSaving = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
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
