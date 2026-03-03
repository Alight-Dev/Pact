//
//  ShieldProgressViewModel.swift
//  Pact
//

import SwiftUI
import Combine

// MARK: - Shield Tier

enum ShieldTier: String, CaseIterable {
    case none     = "No Rank"
    case bronze   = "Bronze"
    case silver   = "Silver"
    case gold     = "Gold"
    case platinum = "Platinum"
    case diamond  = "Diamond"
    case obsidian = "Obsidian"
    case mythic   = "Mythic"

    var color: Color {
        switch self {
        case .none:     return Color(white: 0.50)
        case .bronze:   return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver:   return Color(white: 0.55)
        case .gold:     return Color(red: 0.85, green: 0.70, blue: 0.10)
        case .platinum: return Color(red: 0.60, green: 0.80, blue: 0.90)
        case .diamond:  return Color(red: 0.40, green: 0.70, blue: 1.00)
        case .obsidian: return Color(red: 0.45, green: 0.20, blue: 0.80)
        case .mythic:   return Color(red: 1.00, green: 0.40, blue: 0.20)
        }
    }

    var threshold: Int {
        switch self {
        case .none:     return 0
        case .bronze:   return 5
        case .silver:   return 10
        case .gold:     return 25
        case .platinum: return 50
        case .diamond:  return 100
        case .obsidian: return 180
        case .mythic:   return 365
        }
    }

    static func current(for streakDays: Int) -> ShieldTier {
        let tiers: [ShieldTier] = [.mythic, .obsidian, .diamond, .platinum, .gold, .silver, .bronze]
        for tier in tiers where streakDays >= tier.threshold {
            return tier
        }
        return .none
    }

    static func next(after current: ShieldTier) -> ShieldTier? {
        let ordered: [ShieldTier] = [.none, .bronze, .silver, .gold, .platinum, .diamond, .obsidian, .mythic]
        guard let idx = ordered.firstIndex(of: current), idx + 1 < ordered.count else { return nil }
        return ordered[idx + 1]
    }
}

// MARK: - ViewModel

@MainActor
final class ShieldProgressViewModel: ObservableObject {

    @Published var streakDays: Int = 0
    @Published var currentTier: ShieldTier = .none
    @Published var nextTier: ShieldTier? = .bronze
    @Published var progressToNextTier: CGFloat = 0
    @Published var daysUntilNextTier: Int = 0
    @Published var isMaxTier: Bool = false
    @Published var tierJustUnlocked: Bool = false

    private var cancellable: AnyCancellable?
    private var previousTier: ShieldTier = .none

    /// Observes `firestoreService.currentTeam` for real-time streak updates.
    func observe(_ firestoreService: FirestoreService) {
        cancellable = firestoreService.$currentTeam
            .compactMap { $0 }
            .map { $0["currentStreakDays"] as? Int ?? 0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] days in
                self?.update(streakDays: days)
            }
    }

    private func update(streakDays: Int) {
        self.streakDays = streakDays

        let tier = ShieldTier.current(for: streakDays)
        let next = ShieldTier.next(after: tier)

        if tier != .none && tier != previousTier && previousTier != .none {
            tierJustUnlocked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.tierJustUnlocked = false
            }
        }
        previousTier = tier

        currentTier = tier
        nextTier = next
        isMaxTier = (next == nil)

        if let next {
            let rangeStart = tier.threshold
            let rangeEnd = next.threshold
            let rangeSize = rangeEnd - rangeStart
            let progress = streakDays - rangeStart
            progressToNextTier = rangeSize > 0 ? CGFloat(progress) / CGFloat(rangeSize) : 0
            daysUntilNextTier = rangeEnd - streakDays
        } else {
            progressToNextTier = 1.0
            daysUntilNextTier = 0
        }
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }
}
