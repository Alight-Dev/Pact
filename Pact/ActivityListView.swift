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

    /// Height of one activity row (card + spacing). Used to size the activities region.
    private static let activityRowHeight: CGFloat = 88
    private static let activityRowSpacing: CGFloat = 10
    /// Show first 4 activities without scrolling; 5+ use this max height and scroll.
    private static let activitiesScrollMaxHeight: CGFloat = (4 * activityRowHeight) + (3 * activityRowSpacing) + 16

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 1. Fixed header
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
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // 2. Bounded activities area: fits first 4 without scroll; 5+ scroll inside same max height
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
                    .frame(height: min(200, geo.size.height * 0.28))
                    .padding(.horizontal, 20)
                } else if activities.count <= 4 {
                    // 1–4 activities: no scroll, container grows to fit (no blank gap)
                    VStack(spacing: Self.activityRowSpacing) {
                        ForEach(activities) { activity in
                            activityRowButton(activity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                } else {
                    // 5+: fixed-height scroll
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: Self.activityRowSpacing) {
                            ForEach(activities) { activity in
                                activityRowButton(activity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: Self.activitiesScrollMaxHeight)
                }

                Spacer(minLength: 16)

                // 3. Fixed bottom section: never blocked, predetermined area
                VStack(spacing: 0) {
                    // Initial Conditions card
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    if let error = createTeamError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    // Full-width button row: Continue (65%) + Add Activity (plus, green outline)
                    HStack(spacing: 12) {
                        if let onContinue {
                            Button {
                                isCreatingTeam = true
                                createTeamError = nil
                                let payloads = activities.map { a in
                                    ActivityPayload(
                                        name: a.name,
                                        description: a.activityDescription,
                                        iconName: a.iconName,
                                        repeatDays: a.repeatDays,
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
                            .frame(maxWidth: .infinity)
                        }

                        Button {
                            showingAddActivity = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color(red: 0.2, green: 0.65, blue: 0.4))
                                .frame(width: 56, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(Color(red: 0.2, green: 0.65, blue: 0.4), lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add Activity")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .background(Color.white)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .scrollDismissesKeyboard(.immediately)
        #if DEBUG
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
        .sheet(item: $activityToEdit) { activity in
            AddActivitySheet(existingActivity: activity, onDelete: {
                modelContext.delete(activity)
                try? modelContext.save()
                activityToEdit = nil
            }) { name, description, iconName, repeatDays in
                activity.name = name
                activity.activityDescription = description
                activity.iconName = iconName
                activity.repeatDays = repeatDays
                try? modelContext.save()
                activityToEdit = nil
            }
        }
    }

    @ViewBuilder
    private func activityRowButton(_ activity: Activity) -> some View {
        Button {
            activityToEdit = activity
        } label: {
            ActivityRowView(activity: activity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                activityToEdit = activity
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(activity)
            } label: {
                Label("Delete", systemImage: "trash")
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
    var onDelete: (() -> Void)? = nil
    var onSave: (String, String, String, [Int]) -> Void
    private var isEditing: Bool

    @State private var name: String
    @State private var activityDescription: String
    @State private var selectedIcon: String
    @State private var selectedDays: Set<Int>
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case description
    }

    init(existingActivity: Activity? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (String, String, String, [Int]) -> Void) {
        self.existingActivity = existingActivity
        self.onDelete = onDelete
        self.onSave = onSave
        self.isEditing = existingActivity != nil
        _name = State(initialValue: existingActivity?.name ?? "")
        _activityDescription = State(initialValue: existingActivity?.activityDescription ?? "")
        _selectedIcon = State(initialValue: existingActivity?.iconName ?? "figure.run")
        _selectedDays = State(initialValue: Set(existingActivity?.repeatDays ?? []))
    }

    /// Values-based init for editing a `TeamActivity` from Firestore (no SwiftData dependency).
    init(name: String = "", description: String = "", iconName: String = "figure.run",
         repeatDays: [Int] = [],
         onDelete: (() -> Void)? = nil,
         onSave: @escaping (String, String, String, [Int]) -> Void) {
        self.existingActivity = nil
        self.onDelete = onDelete
        self.onSave = onSave
        self.isEditing = !name.isEmpty
        _name = State(initialValue: name)
        _activityDescription = State(initialValue: description)
        _selectedIcon = State(initialValue: iconName)
        _selectedDays = State(initialValue: Set(repeatDays))
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    @State private var showFullIconPicker = false

    /// Icons with display names for search. First 12 used for 4×3 preview; full list for "View more" sheet.
    private static let activityIconEntries: [(symbol: String, name: String)] = [
        ("figure.run", "Run"), ("figure.walk", "Walk"), ("figure.hiking", "Hiking"), ("dumbbell.fill", "Dumbbell"),
        ("bicycle", "Bicycle"), ("sun.min", "Sun"), ("book.fill", "Book"), ("pencil", "Pencil"),
        ("brain.head.profile", "Brain"), ("fork.knife", "Food"), ("drop.fill", "Water"), ("moon.fill", "Moon"),
        ("heart.fill", "Heart"), ("flame.fill", "Flame"), ("music.note", "Music"), ("camera.fill", "Camera"),
        ("paintbrush.fill", "Paint"), ("gamecontroller.fill", "Gaming"), ("briefcase.fill", "Work"), ("laptopcomputer", "Laptop"),
        ("chart.bar.fill", "Chart"), ("bed.double.fill", "Sleep"), ("person.fill", "Person"), ("stopwatch.fill", "Stopwatch"),
        ("figure.yoga", "Yoga"), ("figure.strengthtraining.traditional", "Strength"), ("figure.outdoor.cycle", "Cycling"),
        ("book.closed.fill", "Reading"), ("graduationcap.fill", "Study"), ("leaf.fill", "Nature"), ("cup.and.saucer.fill", "Tea"),
        ("carrot.fill", "Vegetables"), ("fish.fill", "Fish"), ("paw.print.fill", "Pets"), ("house.fill", "Home"),
        ("envelope.fill", "Mail"), ("phone.fill", "Phone"), ("headphones", "Headphones"), ("guitars", "Guitar"),
        ("paintpalette.fill", "Art"), ("theatermasks.fill", "Theater"), ("binoculars.fill", "Binoculars"), ("globe", "Globe"),
        ("map.fill", "Map"), ("figure.stand", "Stand"), ("figure.arms.open", "Meditation"), ("brain", "Mind"),
        ("lightbulb.fill", "Idea"), ("bolt.fill", "Energy"), ("star.fill", "Star"), ("flag.fill", "Flag"),
        ("bookmark.fill", "Bookmark"), ("tag.fill", "Tag"), ("folder.fill", "Folder"), ("doc.fill", "Document"),
        ("hand.raised.fill", "Hand"), ("hand.thumbsup.fill", "Thumbs up"), ("heart.circle.fill", "Heart circle"), ("sparkles", "Sparkles"),
        ("trophy.fill", "Trophy"), ("medal.fill", "Medal"), ("crown.fill", "Crown"), ("target", "Target"),
        ("scope", "Scope"), ("cross.case.fill", "First aid"), ("pill.fill", "Medicine"), ("stethoscope", "Health"),
        ("hands.sparkles", "Prayer"), ("leaf.circle.fill", "Leaf"), ("flame.circle.fill", "Flame circle"), ("drop.circle.fill", "Drop circle"),
        ("wind", "Wind"), ("snowflake", "Snow"), ("cloud.sun.fill", "Weather"), ("thermometer.medium", "Temperature"),
        ("dice.fill", "Dice"), ("puzzlepiece.extension.fill", "Puzzle"), ("paintbrush.pointed.fill", "Brush"), ("pencil.and.outline", "Write"),
        ("highlighter", "Highlight"), ("scissors", "Scissors"), ("hammer.fill", "Hammer"), ("wrench.fill", "Wrench"),
        ("gearshape.fill", "Settings"), ("bell.fill", "Bell"), ("alarm.fill", "Alarm"),
    ]

    private static let activityIconNames: [String] = activityIconEntries.map(\.symbol)
    private static let previewIconCount = 12
    private static let iconColumns = 4
    private let previewColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: Self.iconColumns)
    /// Preview shows selected icon in first slot, then up to 11 others.
    private var previewIcons: [String] {
        let rest = Self.activityIconNames.filter { $0 != selectedIcon }
        return [selectedIcon] + rest.prefix(Self.previewIconCount - 1)
    }

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
                                selectedDays.sorted()
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

                        // Icon picker — 4×3 preview + View more
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.55))
                                .kerning(0.6)

                            LazyVGrid(columns: previewColumns, spacing: 14) {
                                ForEach(previewIcons, id: \.self) { icon in
                                    Button {
                                        focusedField = nil
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 28))
                                            .foregroundStyle(selectedIcon == icon ? .white : Color(white: 0.45))
                                            .frame(width: 56, height: 56)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon ? Color.black : Color(white: 0.92))
                                            )
                                    }
                                }
                            }

                            Button {
                                focusedField = nil
                                showFullIconPicker = true
                            } label: {
                                Text("View more")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(white: 0.92))
                                    )
                            }
                        }

                        // Repeat Days picker
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Repeat Days")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.black)
                                    Text("Every day")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(white: 0.50))
                                }
                                Spacer()
                                let allSelected = selectedDays.count == 7
                                Button {
                                    selectedDays = allSelected ? [] : Set(0...6)
                                } label: {
                                    Text("All")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(allSelected ? .white : .black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(allSelected ? Color.black : Color(white: 0.88))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

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

                        // Delete Activity — only when editing and onDelete provided
                        if isEditing, onDelete != nil {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Delete Activity")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red)
                                )
                            }
                            .padding(.top, 8)
                        }

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
        .alert("Delete Activity", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This activity will be permanently deleted. This cannot be undone.")
        }
        .sheet(isPresented: $showFullIconPicker) {
            FullScreenIconPicker(
                entries: Self.activityIconEntries,
                selectedIcon: $selectedIcon,
                onDismiss: { showFullIconPicker = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - FullScreenIconPicker

private struct FullScreenIconPicker: View {
    let entries: [(symbol: String, name: String)]
    @Binding var selectedIcon: String
    var onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    /// Selected icon first, then rest (no duplicate). Filtered by search.
    private var orderedFilteredEntries: [(symbol: String, name: String)] {
        let filtered = searchText.isEmpty
            ? entries
            : entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let selected = filtered.first { $0.symbol == selectedIcon }
        let rest = filtered.filter { $0.symbol != selectedIcon }
        if let s = selected {
            return [s] + rest
        }
        return rest
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with trailing Done button (sheet can also be dismissed by dragging down)
                HStack {
                    Spacer()
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.55))
                    TextField("Search icons", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                        .tint(.black)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.94))
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(orderedFilteredEntries, id: \.symbol) { entry in
                            Button {
                                selectedIcon = entry.symbol
                                onDismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: entry.symbol)
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIcon == entry.symbol ? .white : Color(white: 0.45))
                                        .frame(width: 56, height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == entry.symbol ? Color.black : Color(white: 0.92))
                                        )
                                    Text(entry.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(white: 0.5))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
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
