import XCTest
@testable import BrainrotAlarm

final class ChallengeEngineTests: XCTestCase {

    private var pool: [BrainrotCharacter] { BrainrotCatalog.all }

    // MARK: - Round construction

    func testGridSizeAndAnswerPresence() {
        for difficulty in Difficulty.allCases {
            let session = ChallengeSession(difficulty: difficulty, pool: pool, seed: 7)
            XCTAssertEqual(session.rounds.count, difficulty.roundsRequired)
            for round in session.rounds {
                XCTAssertEqual(round.options.count, difficulty.gridCount,
                               "\(difficulty) should show \(difficulty.gridCount) tiles")
                XCTAssertTrue(round.options.contains { $0.id == round.answer.id },
                              "the answer has to be on screen")
                XCTAssertEqual(Set(round.options.map(\.id)).count, round.options.count,
                               "no duplicate tiles")
            }
        }
    }

    func testHarderDifficultiesChooseMoreConfusableDecoys() {
        // Averaged over many draws, nightmare decoys should sit measurably closer
        // to the answer than gentle ones.
        func meanDistance(_ difficulty: Difficulty) -> Double {
            var total = 0.0
            var count = 0
            for seed in 0..<60 {
                var generator = SeededGenerator(seed: UInt64(seed))
                let round = ChallengeSession.makeRound(difficulty: difficulty,
                                                       pool: pool,
                                                       using: &generator)
                for option in round.options where option.id != round.answer.id {
                    total += round.answer.distance(to: option)
                    count += 1
                }
            }
            return total / Double(count)
        }

        let gentle = meanDistance(.gentle)
        let nightmare = meanDistance(.nightmare)
        XCTAssertGreaterThan(gentle, nightmare * 1.5,
                             "gentle=\(gentle) nightmare=\(nightmare): the gradient collapsed")
    }

    func testForcedFirstAnswer() {
        let target = BrainrotCatalog.character(id: "bombardiro")!
        let session = ChallengeSession(difficulty: .brutal, pool: pool, seed: 3,
                                       forcedFirstAnswer: target)
        XCTAssertEqual(session.rounds[0].answer.id, target.id)
        XCTAssertTrue(session.rounds[0].options.contains { $0.id == target.id })
    }

    func testSmallPoolDoesNotCrashOrDuplicate() {
        for size in 1...6 {
            let small = Array(pool.prefix(size))
            for difficulty in Difficulty.allCases {
                let session = ChallengeSession(difficulty: difficulty, pool: small, seed: 11)
                for round in session.rounds {
                    XCTAssertEqual(Set(round.options.map(\.id)).count, round.options.count)
                    XCTAssertLessThanOrEqual(round.options.count, difficulty.gridCount)
                    XCTAssertTrue(round.options.contains { $0.id == round.answer.id })
                }
            }
        }
    }

    // MARK: - Playing

    func testCorrectAnswersAdvanceAndSolve() {
        var session = ChallengeSession(difficulty: .standard, pool: pool, seed: 5)
        XCTAssertEqual(session.select(session.currentRound!.answer.id), .correct)
        XCTAssertEqual(session.progress.done, 1)
        XCTAssertEqual(session.select(session.currentRound!.answer.id), .solved)
        XCTAssertTrue(session.isSolved)
        XCTAssertEqual(session.misses, 0)
    }

    func testWrongAnswerLocksTheGrid() {
        var session = ChallengeSession(difficulty: .standard, pool: pool, seed: 5)
        let round = session.currentRound!
        let wrong = round.options.first { $0.id != round.answer.id }!
        let start = Date()

        XCTAssertEqual(session.select(wrong.id, now: start), .wrong(lockout: Difficulty.standard.missLockout))
        XCTAssertEqual(session.misses, 1)
        XCTAssertTrue(session.isLocked(at: start))

        // Taps during the lockout are swallowed, including correct ones.
        XCTAssertEqual(session.select(round.answer.id, now: start.addingTimeInterval(0.2)), .ignored)
        XCTAssertEqual(session.progress.done, 0)

        let after = start.addingTimeInterval(Difficulty.standard.missLockout + 0.1)
        XCTAssertFalse(session.isLocked(at: after))
        XCTAssertEqual(session.select(session.currentRound!.answer.id, now: after), .correct)
    }

    func testBrutalAddsARoundOnAMiss() {
        var session = ChallengeSession(difficulty: .brutal, pool: pool, seed: 5)
        let before = session.rounds.count
        let round = session.currentRound!
        let wrong = round.options.first { $0.id != round.answer.id }!
        _ = session.select(wrong.id)
        XCTAssertEqual(session.rounds.count, before + 1, "brutal punishes a miss with more work")
    }

    func testNightmareRestartsButKeepsTheChantYouHeard() {
        var session = ChallengeSession(difficulty: .nightmare, pool: pool, seed: 5)
        let firstAnswer = session.rounds[0].answer.id
        _ = session.select(session.currentRound!.answer.id)
        XCTAssertEqual(session.progress.done, 1)

        let round = session.currentRound!
        let wrong = round.options.first { $0.id != round.answer.id }!
        _ = session.select(wrong.id)

        XCTAssertEqual(session.progress.done, 0, "nightmare sends you back to the start")
        XCTAssertEqual(session.rounds[0].answer.id, firstAnswer,
                       "restarting onto an unheard chant would be unfair")
    }

    func testSolvedSessionIgnoresFurtherTaps() {
        var session = ChallengeSession(difficulty: .gentle, pool: pool, seed: 5)
        XCTAssertEqual(session.select(session.currentRound!.answer.id), .solved)
        XCTAssertEqual(session.select(pool[0].id), .ignored)
    }

    func testSeededSessionsReplayIdentically() {
        let a = ChallengeSession(difficulty: .brutal, pool: pool, seed: 42)
        let b = ChallengeSession(difficulty: .brutal, pool: pool, seed: 42)
        XCTAssertEqual(a.rounds.map(\.answer.id), b.rounds.map(\.answer.id))
        XCTAssertEqual(a.rounds.map { $0.options.map(\.id) },
                       b.rounds.map { $0.options.map(\.id) })
    }
}

final class CatalogTests: XCTestCase {

    func testIdentifiersAreUnique() {
        let ids = BrainrotCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testTiersAreUsable() {
        // Every tier has to be able to fill the biggest grid.
        for tier in [BrainrotCharacter.Tier.starter, .core, .deep] {
            let pool = BrainrotCatalog.characters(upTo: tier)
            XCTAssertGreaterThanOrEqual(pool.count, 8, "\(tier) has too few characters")
        }
        XCTAssertEqual(BrainrotCatalog.characters(upTo: .deep).count, BrainrotCatalog.all.count)
    }

    func testNoTwoCharactersAreIndistinguishable() {
        var closest = Double.greatestFiniteMagnitude
        var offenders = ("", "")
        for (index, a) in BrainrotCatalog.all.enumerated() {
            for b in BrainrotCatalog.all.dropFirst(index + 1) {
                let d = a.distance(to: b)
                if d < closest { closest = d; offenders = (a.id, b.id) }
            }
        }
        XCTAssertGreaterThan(closest, 0.5,
                             "\(offenders.0) and \(offenders.1) are too alike to be a fair round")
    }

    func testEveryCharacterHasEnoughObviouslyDifferentPartners() {
        // A gentle 3-tile round needs two decoys that are clearly not the answer.
        for character in BrainrotCatalog.all {
            let far = BrainrotCatalog.all.filter { $0.id != character.id && character.distance(to: $0) > 2 }
            XCTAssertGreaterThanOrEqual(far.count, 8, "\(character.id) has too few easy decoys")
        }
    }

    func testCastingIsDeterministic() {
        let alarm = AlarmItem(hour: 7, minute: 0, tierCeiling: .deep)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = AlarmCasting.character(for: alarm, firingAt: date)
        let second = AlarmCasting.character(for: alarm, firingAt: date)
        XCTAssertEqual(first.id, second.id,
                       "the scheduler and the app must independently agree on the answer")
    }

    func testCastingRespectsPinning() {
        var alarm = AlarmItem(tierCeiling: .deep)
        alarm.pinnedCharacterID = "girafa"
        XCTAssertEqual(AlarmCasting.character(for: alarm, firingAt: Date()).id, "girafa")
    }

    func testCastingStaysInsideTheTier() {
        let alarm = AlarmItem(tierCeiling: .starter)
        let allowed = Set(BrainrotCatalog.characters(upTo: .starter).map(\.id))
        for minute in 0..<200 {
            let date = Date(timeIntervalSince1970: 1_800_000_000 + Double(minute) * 60)
            XCTAssertTrue(allowed.contains(AlarmCasting.character(for: alarm, firingAt: date).id))
        }
    }

    func testCastingVariesDayToDay() {
        // The case that matters: a repeating alarm at the same clock time. Adding
        // the minute-slot into the hash instead of mixing it makes every morning
        // land on the same character, because a day is a whole number of rosters.
        let alarm = AlarmItem(hour: 7, minute: 0, tierCeiling: .deep)
        var seen = Set<String>()
        for day in 0..<21 {
            let date = Date(timeIntervalSince1970: 1_800_000_000 + Double(day) * 86_400)
            seen.insert(AlarmCasting.character(for: alarm, firingAt: date).id)
        }
        XCTAssertGreaterThan(seen.count, 6,
                             "only \(seen.count) distinct characters in three weeks of a daily alarm")
    }

    func testCastingIsStableAcrossANotificationChain() {
        // Every link in a chain fires within the same minute-ish window and must
        // agree on the answer, or the sound and the grid would disagree.
        let alarm = AlarmItem(hour: 7, minute: 0, tierCeiling: .deep)
        let fire = Date(timeIntervalSince1970: 1_800_000_000)
        let expected = AlarmCasting.character(for: alarm, firingAt: fire).id
        XCTAssertEqual(AlarmCasting.character(for: alarm, firingAt: fire.addingTimeInterval(29)).id,
                       expected)
    }
}
