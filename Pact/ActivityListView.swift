//
//  ActivityListView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - ActivityListView

struct ActivityListView: View {
    var teamName: String = ""
    var onContinue: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Activity.order), SortDescriptor(\Activity.createdAt)])
    private var activities: [Activity]

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreService: FirestoreService

    @State private var showingAddActivity = false
    @State private var activityToEdit: Activity? = nil
    @State private var isCreatingTeam = false
    @State private var createTeamError: String?
    @State private var allowAIFallback: Bool = true
    @State private var minApprovers: Int = 0
    @State private var showDebugSheet: Bool = false
    @State private var showDeleteAccountAlert = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            List {
                // Scrollable header row
                HStack(spacing: 10) {
                    Text("Activities")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.black)
                        .lineSpacing(2)

                    Spacer()

                    HStack(spacing: 12) {
                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)

                        #if DEBUG
                        Button {
                            showDebugSheet = true
                        } label: {
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(white: 0.35))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color(white: 0.94))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Debug account actions")
                        #endif
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 36, trailing: 24))

                if activities.isEmpty {
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
                    ForEach(activities) { activity in
                        Button {
                            activityToEdit = activity
                        } label: {
                            ActivityRowView(activity: activity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // Swipe right → reveal Delete button
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(activity)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .foregroundStyle(.black)
                            }
                        }
                        // Swipe left → reveal Edit button
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

                    // AI fallback row
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

                    // Min approvers row
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

                // Bottom padding so the last card isn't hidden behind the Add button
                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                if let onContinue {
                    VStack(spacing: 6) {
                        Button {
                            isCreatingTeam = true
                            createTeamError = nil
                            let payloads = activities.map { a in
                                ActivityPayload(
                                    name: a.name,
                                    description: a.activityDescription,
                                    iconName: a.iconName,
                                    repeatDays: a.repeatDays,
                                    isOptional: a.isOptional,
                                    order: a.order
                                )
                            }
                            let resolvedName = teamName.isEmpty
                                ? (authManager.currentUser?.displayName?
                                    .components(separatedBy: " ").first.map { "\($0)'s Shield" } ?? "My Shield")
                                : teamName
                            Task {
                                do {
                                    let result = try await firestoreService.createTeam(
                                        name: resolvedName,
                                        activities: payloads,
                                        timezone: TimeZone.current.identifier
                                    )
                                    await MainActor.run {
                                        firestoreService.startTeamSession(
                                            teamId: result.teamId,
                                            teamName: resolvedName,
                                            adminTimezone: TimeZone.current.identifier
                                        )
                                        onContinue(result.inviteCode)
                                    }
                                } catch {
                                    createTeamError = error.localizedDescription
                                }
                                isCreatingTeam = false
                            }
                        } label: {
                            Group {
                                if isCreatingTeam {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(activities.isEmpty || isCreatingTeam ? Color(white: 0.9) : Color.black)
                            )
                            .foregroundStyle(activities.isEmpty || isCreatingTeam ? Color(white: 0.7) : .white)
                        }
                        .disabled(activities.isEmpty || isCreatingTeam)

                        if let error = createTeamError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // Fixed Add Activity button
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        #if DEBUG
        // TODO: Remove debug account controls before production.
        .confirmationDialog(
            "Debug Account Actions",
            isPresented: $showDebugSheet,
            titleVisibility: .visible
        ) {
            Button("Sign Out") {
                try? authManager.signOut()
            }
            Button("Delete Account", role: .destructive) {
                showDeleteAccountAlert = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await authManager.deleteAccount()
                    try? modelContext.delete(model: Activity.self)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and resets the app. You cannot undo this.")
        }
        #endif
        // Add sheet
        .sheet(isPresented: $showingAddActivity) {
            AddActivitySheet { name, description, iconName, repeatDays, isOptional in
                let activity = Activity(
                    name: name,
                    activityDescription: description,
                    iconName: iconName,
                    order: activities.count,
                    repeatDays: repeatDays,
                    isOptional: isOptional
                )
                modelContext.insert(activity)
                showingAddActivity = false
            }
        }
        // Edit sheet — pre-fills form with the tapped activity's current values
        .sheet(item: $activityToEdit) { activity in
            AddActivitySheet(existingActivity: activity) { name, description, iconName, repeatDays, isOptional in
                activity.name = name
                activity.activityDescription = description
                activity.iconName = iconName
                activity.repeatDays = repeatDays
                activity.isOptional = isOptional
                activityToEdit = nil
            }
        }
    }
}

// MARK: - ActivityRowView

struct ActivityRowView: View {
    let activity: Activity

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
        // "X Days" label pinned to the bottom-right of the card
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

// MARK: - AddActivitySheet

struct AddActivitySheet: View {
    var existingActivity: Activity? = nil
    var onSave: (String, String, String, [Int], Bool) -> Void
    private var isEditing: Bool

    @State private var name: String
    @State private var activityDescription: String
    @State private var selectedIcon: String
    @State private var selectedDays: Set<Int>
    @State private var isOptional: Bool
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case description
    }

    init(existingActivity: Activity? = nil, onSave: @escaping (String, String, String, [Int], Bool) -> Void) {
        self.existingActivity = existingActivity
        self.onSave = onSave
        self.isEditing = existingActivity != nil
        _name = State(initialValue: existingActivity?.name ?? "")
        _activityDescription = State(initialValue: existingActivity?.activityDescription ?? "")
        _selectedIcon = State(initialValue: existingActivity?.iconName ?? "figure.run")
        _selectedDays = State(initialValue: Set(existingActivity?.repeatDays ?? []))
        _isOptional = State(initialValue: existingActivity?.isOptional ?? false)
    }

    /// Values-based init for editing a `TeamActivity` from Firestore (no SwiftData dependency).
    init(name: String = "", description: String = "", iconName: String = "figure.run",
         repeatDays: [Int] = [], isOptional: Bool = false,
         onSave: @escaping (String, String, String, [Int], Bool) -> Void) {
        self.existingActivity = nil
        self.onSave = onSave
        self.isEditing = !name.isEmpty
        _name = State(initialValue: name)
        _activityDescription = State(initialValue: description)
        _selectedIcon = State(initialValue: iconName)
        _selectedDays = State(initialValue: Set(repeatDays))
        _isOptional = State(initialValue: isOptional)
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private let icons = [
        "figure.run", "figure.walk", "figure.hiking",
        "dumbbell.fill", "bicycle", "sun.min",
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

    private var canSave: Bool {
        !trimmedName.isEmpty && !selectedDays.isEmpty
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

                    Text(isEditing ? "Edit Activity" : "New Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    Button("Save") {
                        if canSave {
                            onSave(
                                trimmedName,
                                activityDescription.trimmingCharacters(in: .whitespaces),
                                selectedIcon,
                                selectedDays.sorted(),
                                isOptional
                            )
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? .black : Color(white: 0.75))
                    .disabled(!canSave)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)

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
                                .textInputAutocapitalization(.sentences)
                                .onChange(of: name) { _, newValue in
                                    if newValue.count > 20 {
                                        name = String(newValue.prefix(20))
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.94))
                                )
                                .focused($focusedField, equals: .name)
                                .submitLabel(.done)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .name
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
                                .textInputAutocapitalization(.sentences)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.94))
                                )
                                .focused($focusedField, equals: .description)
                                .submitLabel(.done)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .description
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
                                        focusedField = nil
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
                            HStack {
                                Text("Repeat Days")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.black)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { selectedDays.count == 7 },
                                    set: { on in
                                        selectedDays = on ? Set(0...6) : []
                                    }
                                ))
                                .labelsHidden()
                                .tint(.black)
                            }

                            Text("Every day")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.50))

                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { index in
                                    let isSelected = selectedDays.contains(index)
                                    Button {
                                        focusedField = nil
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

                        // Optional toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OPTIONAL")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.55))
                                    .kerning(0.6)
                                Text("Members can choose whether to opt in")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(white: 0.55))
                            }
                            Spacer()
                            Toggle("", isOn: $isOptional)
                                .labelsHidden()
                                .tint(.black)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.94))
                        )

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
                .scrollDismissesKeyboard(.immediately)
                .onSubmit {
                    focusedField = nil
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ApproverSegmentedPicker

struct ApproverSegmentedPicker: View {
    @Binding var selection: Int  // 0 = 1 Person, 1 = 50% of Team, 2 = Entire Team

    private let segments = ["1 Person", "50% of Team", "Entire Team"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segments.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = index
                    }
                } label: {
                    Text(segments[index])
                        .font(.system(size: 13, weight: selection == index ? .semibold : .regular))
                        .foregroundStyle(selection == index ? .white : Color(white: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selection == index ? Color.black : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    ActivityListView()
        .modelContainer(for: Activity.self, inMemory: true)
        .environmentObject(AuthManager())
        .environmentObject(FirestoreService())
}
