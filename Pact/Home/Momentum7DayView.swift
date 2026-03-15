//
//  Momentum7DayView.swift
//  Pact
//
//  7-day rolling bar chart per member, stagger-animates on appear.
//

import SwiftUI

struct Momentum7DayView: View {
    let members: [TeamMember]
    let recentSubmissions: [[String: Any]]     // raw Firestore docs for past 7 days

    @State private var animationProgress: [String: [CGFloat]] = [:]
    @State private var appeared = false

    // Compute per-member 7-day booleans from submission data
    private var memberData: [(member: TeamMember, days: [Bool])] {
        members.map { member in
            let days: [Bool] = (0..<7).map { offset in
                let date = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: Date())!
                let dateStr = DateFormatter.pactDate.string(from: date)
                return recentSubmissions.contains {
                    ($0["submitterUid"] as? String) == member.id &&
                    ($0["date"] as? String) == dateStr &&
                    (($0["status"] as? String) == "approved" || ($0["status"] as? String) == "auto_approved")
                }
            }
            return (member, days)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("7-Day Momentum")
                    .font(PactFont.sectionTitle)
                    .foregroundStyle(Color.pactTextPrimary)
                Spacer()
                Text("Team Average: \(teamAverage)%")
                    .font(PactFont.caption)
                    .foregroundStyle(Color.pactTextSecond)
            }
            .padding(.bottom, 16)

            if members.isEmpty {
                Text("No team members yet.")
                    .font(PactFont.bodySmall)
                    .foregroundStyle(Color.pactTextMuted)
            } else {
                // Day label row
                HStack(spacing: 0) {
                    ForEach(dayLabels, id: \.self) { label in
                        Text(label)
                            .font(PactFont.micro)
                            .foregroundStyle(Color.pactTextMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.leading, 48)
                .padding(.bottom, 8)

                // Member rows
                VStack(spacing: 14) {
                    ForEach(Array(memberData.enumerated()), id: \.element.member.id) { idx, entry in
                        memberRow(entry: entry, rowIndex: idx)
                    }
                }
            }
        }
    }

    // MARK: - Member Row

    private func memberRow(entry: (member: TeamMember, days: [Bool]), rowIndex: Int) -> some View {
        HStack(spacing: 10) {
            // Avatar
            avatarCircle(member: entry.member)
                .frame(width: 32, height: 32)

            // Bars
            HStack(spacing: 4) {
                ForEach(Array(entry.days.enumerated()), id: \.offset) { dayIdx, completed in
                    let prog = animationProgress[entry.member.id]?[safe: dayIdx] ?? 0
                    bar(completed: completed, animatedProgress: prog, isToday: dayIdx == 6)
                }
            }
        }
        .onAppear {
            guard !appeared || animationProgress[entry.member.id] == nil else { return }
            if rowIndex == 0 { appeared = true }
            let baseDelay = Double(rowIndex) * 0.06
            for dayIdx in 0..<7 {
                let delay = baseDelay + Double(dayIdx) * 0.04
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        var current = animationProgress[entry.member.id] ?? Array(repeating: 0, count: 7)
                        if current.count <= dayIdx { current.append(contentsOf: Array(repeating: 0, count: dayIdx - current.count + 1)) }
                        current[dayIdx] = 1
                        animationProgress[entry.member.id] = current
                    }
                }
            }
        }
    }

    // MARK: - Bar

    private func bar(completed: Bool, animatedProgress: CGFloat, isToday: Bool) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.pactSurface3)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AnyShapeStyle(
                            isToday
                            ? (completed ? AnyShapeStyle(LinearGradient.pactGold) : AnyShapeStyle(Color.pactAmber.opacity(0.5)))
                            : (completed ? AnyShapeStyle(LinearGradient.pactGold) : AnyShapeStyle(Color.pactSurface3))
                        ))
                        .frame(height: completed ? geo.size.height * animatedProgress : 4)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatarCircle(member: TeamMember) -> some View {
        if !member.avatarAssetName.isEmpty,
           UIImage(named: member.avatarAssetName) != nil {
            Image(member.avatarAssetName)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.pactSurface3)
                .overlay(
                    Text(String(
                        (member.nickname.isEmpty ? member.displayName : member.nickname)
                            .prefix(1)
                    ).uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.pactAccent)
                )
        }
    }

    // MARK: - Helpers

    private var dayLabels: [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: Date())!
            return String(fmt.string(from: date).prefix(1)).uppercased()
        }
    }

    private var teamAverage: Int {
        let data = memberData
        guard !data.isEmpty else { return 0 }
        let total = data.reduce(0) { $0 + $1.days.filter { $0 }.count }
        let possible = data.count * 7
        return possible > 0 ? Int(round(Double(total) / Double(possible) * 100)) : 0
    }
}

// MARK: - Helpers

private extension DateFormatter {
    static let pactDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.pactBackground.ignoresSafeArea()
        Momentum7DayView(members: [], recentSubmissions: [])
            .padding(24)
    }
}
