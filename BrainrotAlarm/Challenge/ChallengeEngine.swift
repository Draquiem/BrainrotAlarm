import Foundation

/// How hard it is to shut the alarm up.
enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case gentle, standard, brutal, nightmare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: return "Gentle"
        case .standard: return "Standard"
        case .brutal: return "Brutal"
        case .nightmare: return "Nightmare"
        }
    }

    var blurb: String {
        switch self {
        case .gentle: return "3 tiles, 1 round, nothing similar. For soft landings."
        case .standard: return "4 tiles, 2 rounds. The default."
        case .brutal: return "6 tiles, 3 rounds, similar-sounding decoys. A miss adds a round."
        case .nightmare: return "9 tiles, 3 rounds, the closest decoys, no replays. A miss starts you over."
        }
    }

    var gridCount: Int {
        switch self {
        case .gentle: return 3
        case .standard: return 4
        case .brutal: return 6
        case .nightmare: return 9
        }
    }

    var roundsRequired: Int {
        switch self {
        case .gentle: return 1
        case .standard: return 2
        case .brutal, .nightmare: return 3
        }
    }

    var allowsReplay: Bool { self != .nightmare }

    /// Seconds a wrong tap locks the grid for. Stops you from mashing your way out.
    var missLockout: TimeInterval {
        switch self {
        case .gentle: return 0.6
        case .standard: return 1.0
        case .brutal: return 1.5
        case .nightmare: return 2.5
        }
    }

    /// Which slice of the confusability ranking the decoys come from.
    /// 0 is the most confusable character available, 1 the least.
    fileprivate var decoyBand: ClosedRange<Double> {
        switch self {
        case .gentle: return 0.55...1.0
        case .standard: return 0.25...0.85
        case .brutal: return 0.0...0.5
        case .nightmare: return 0.0...0.3
        }
    }

    fileprivate var penalty: MissPenalty {
        switch self {
        case .gentle, .standard: return .reshuffle
        case .brutal: return .addRound
        case .nightmare: return .restart
        }
    }
}

fileprivate enum MissPenalty {
    case reshuffle, addRound, restart
}

/// One question: play this character's chant, show these tiles.
struct ChallengeRound: Identifiable {
    let id = UUID()
    let answer: BrainrotCharacter
    var options: [BrainrotCharacter]
}

/// The result of tapping a tile.
enum TapOutcome: Equatable {
    case correct
    case solved
    case wrong(lockout: TimeInterval)
    case ignored          // tapped during the lockout
}

/// A run at dismissing one alarm.
///
/// Deliberately a plain value type with no SwiftUI, Foundation timers or audio in
/// it, so the rules can be tested directly.
struct ChallengeSession {

    let difficulty: Difficulty
    private(set) var rounds: [ChallengeRound]
    private(set) var index: Int = 0
    private(set) var misses: Int = 0
    private(set) var isSolved: Bool = false
    /// Set after a wrong tap; the view refuses input until this passes.
    private(set) var lockedUntil: Date?

    private var generator: SeededGenerator
    private let pool: [BrainrotCharacter]

    /// - Parameter forcedFirstAnswer: pins round one to a specific character.
    ///   The notification has already played somebody's chant by the time the app
    ///   opens, so the first question has to be about that character.
    init(difficulty: Difficulty,
         pool: [BrainrotCharacter],
         seed: UInt64 = UInt64.random(in: 0...UInt64.max),
         forcedFirstAnswer: BrainrotCharacter? = nil) {
        self.difficulty = difficulty
        self.pool = pool
        self.generator = SeededGenerator(seed: seed)
        self.rounds = []
        self.rounds = (0..<difficulty.roundsRequired).enumerated().map { offset, _ in
            ChallengeSession.makeRound(difficulty: difficulty,
                                       pool: pool,
                                       answer: offset == 0 ? forcedFirstAnswer : nil,
                                       using: &generator)
        }
    }

    var currentRound: ChallengeRound? {
        index < rounds.count ? rounds[index] : nil
    }

    var progress: (done: Int, total: Int) { (index, rounds.count) }

    func isLocked(at now: Date) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }

    /// Tap a tile. Everything the view needs to react is in the returned outcome.
    mutating func select(_ characterID: String, now: Date = Date()) -> TapOutcome {
        guard !isSolved else { return .ignored }
        guard !isLocked(at: now) else { return .ignored }
        guard let round = currentRound else { return .ignored }

        if characterID == round.answer.id {
            lockedUntil = nil
            index += 1
            if index >= rounds.count {
                isSolved = true
                return .solved
            }
            return .correct
        }

        misses += 1
        lockedUntil = now.addingTimeInterval(difficulty.missLockout)

        switch difficulty.penalty {
        case .reshuffle:
            rounds[index].options.shuffle(using: &generator)
        case .addRound:
            rounds[index].options.shuffle(using: &generator)
            rounds.append(ChallengeSession.makeRound(difficulty: difficulty, pool: pool, using: &generator))
        case .restart:
            // Keep the character you already failed on as round one — restarting
            // onto a brand new chant you have not heard yet would be unfair.
            let keep = rounds.first?.answer
            index = 0
            rounds = (0..<difficulty.roundsRequired).enumerated().map { offset, _ in
                ChallengeSession.makeRound(difficulty: difficulty,
                                           pool: pool,
                                           answer: offset == 0 ? keep : nil,
                                           using: &generator)
            }
        }
        return .wrong(lockout: difficulty.missLockout)
    }

    // MARK: - Round construction

    static func makeRound(difficulty: Difficulty,
                          pool: [BrainrotCharacter],
                          answer forced: BrainrotCharacter? = nil,
                          using generator: inout SeededGenerator) -> ChallengeRound {
        precondition(!pool.isEmpty, "the roster cannot be empty")
        let answer = forced ?? pool.randomElement(using: &generator)!
        var options = decoys(for: answer,
                             pool: pool,
                             count: difficulty.gridCount - 1,
                             difficulty: difficulty,
                             using: &generator)
        options.append(answer)
        options.shuffle(using: &generator)
        return ChallengeRound(answer: answer, options: options)
    }

    /// Picks wrong answers from a slice of the confusability ranking.
    ///
    /// Sorting by `distance` puts the easiest-to-mistake characters first, so
    /// `gentle` draws from the far end and `nightmare` from the near end. The band
    /// widens automatically if the roster is too small to fill it.
    static func decoys(for answer: BrainrotCharacter,
                       pool: [BrainrotCharacter],
                       count: Int,
                       difficulty: Difficulty,
                       using generator: inout SeededGenerator) -> [BrainrotCharacter] {
        guard count > 0 else { return [] }
        let others = pool
            .filter { $0.id != answer.id }
            .sorted { answer.distance(to: $0) < answer.distance(to: $1) }
        guard !others.isEmpty else { return [] }
        guard others.count > count else { return Array(others.prefix(count)) }

        let band = difficulty.decoyBand
        var lower = Int((Double(others.count) * band.lowerBound).rounded(.down))
        var upper = Int((Double(others.count) * band.upperBound).rounded(.up))
        upper = min(upper, others.count)
        lower = max(0, min(lower, upper - 1))

        // Widen symmetrically until the band can actually supply `count` decoys.
        while upper - lower < count {
            if lower > 0 { lower -= 1 }
            else if upper < others.count { upper += 1 }
            else { break }
        }
        return Array(others[lower..<upper].shuffled(using: &generator).prefix(count))
    }
}

/// `RandomNumberGenerator` on top of the same xorshift the synthesiser uses, so a
/// seeded session replays exactly — which is the only way to test shuffling.
struct SeededGenerator: RandomNumberGenerator {
    private var source: DeterministicRandom

    init(seed: UInt64) { source = DeterministicRandom(seed: seed) }

    mutating func next() -> UInt64 { source.nextUInt64() }
}
