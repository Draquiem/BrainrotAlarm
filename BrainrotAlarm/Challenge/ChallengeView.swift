import SwiftUI

/// The screen you are looking at when the alarm goes off.
///
/// A chant is playing on a loop. Somewhere in the grid is the creature making it.
/// Tap the right one — the required number of times — and it stops.
@MainActor
struct ChallengeView: View {

    let context: RingingContext

    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: AlarmRouter
    @StateObject private var audio = AlarmAudioEngine.shared
    @Environment(\.dismiss) private var dismiss

    @State private var session: ChallengeSession
    @State private var now = Date()
    @State private var feedback: Feedback?
    @State private var snoozesUsed = 0
    @State private var hasStarted = false
    @State private var solvedAt: Date?

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private struct Feedback: Equatable {
        let characterID: String
        let isCorrect: Bool
    }

    init(context: RingingContext) {
        self.context = context
        let summonedCharacter = AlarmCasting.character(for: context.alarm, firingAt: context.firedAt)
        _session = State(initialValue: ChallengeSession(
            difficulty: context.alarm.difficulty,
            pool: context.alarm.pool(),
            forcedFirstAnswer: summonedCharacter))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if session.isSolved {
                solvedPanel
            } else {
                challengePanel
            }
        }
        .onReceive(ticker) { now = $0 }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await startRound()
        }
        .onDisappear { audio.stop() }
    }

    // MARK: - Challenge

    private var challengePanel: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            listeningPanel
            Spacer(minLength: 8)
            grid
            footer
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(context.alarm.label.isEmpty ? "Alarm" : context.alarm.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 6) {
                ForEach(0..<session.rounds.count, id: \.self) { index in
                    Capsule()
                        .fill(index < session.progress.done ? Theme.accent : Color.white.opacity(0.16))
                        .frame(width: index == session.progress.done ? 22 : 12, height: 5)
                        .animation(.spring(duration: 0.3), value: session.progress.done)
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 20)
    }

    private var listeningPanel: some View {
        VStack(spacing: 12) {
            EqualizerBars(isAnimating: audio.isRinging && !isLocked)
                .frame(height: 34)

            Text(isLocked ? "Wrong. Listen again." : "Who is chanting?")
                .font(.title3.weight(.bold))
                .foregroundStyle(isLocked ? Color(hex: 0xFF6B6B) : .white)
                .contentTransition(.opacity)

            if context.alarm.difficulty.allowsReplay {
                Button {
                    Task { await audio.replayCurrent() }
                } label: {
                    Label("Play it again", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.surfaceRaised))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
                .disabled(isLocked)
            } else {
                Text("No replays on Nightmare.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var grid: some View {
        let options = session.currentRound?.options ?? []
        return LazyVGrid(columns: columns(for: options.count), spacing: 12) {
            ForEach(options) { character in
                CreatureTile(
                    character: character,
                    state: tileState(for: character),
                    action: { tap(character) })
                .disabled(isLocked)
            }
        }
        .animation(.spring(duration: 0.35), value: session.currentRound?.id)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if isLocked, let until = session.lockedUntil {
                Text("Locked for \(max(0, until.timeIntervalSince(now)), format: .number.precision(.fractionLength(1)))s")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(hex: 0xFF6B6B))
            }
            if canSnooze {
                Button(action: snooze) {
                    Text("Snooze \(context.alarm.snoozeMinutes) min · \(context.alarm.maxSnoozes - snoozesUsed) left")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
            }
            if session.misses > 0 {
                Text("\(session.misses) wrong \(session.misses == 1 ? "guess" : "guesses")")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Solved

    private var solvedPanel: some View {
        VStack(spacing: 20) {
            Spacer()
            if let character = session.rounds.last?.answer {
                CreatureView(recipe: character.art)
                    .frame(width: 190, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                Text(character.name)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            Text("Silenced.")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(Theme.accent)
            if let solvedAt {
                Text("\(solvedAt.timeIntervalSince(context.firedAt), format: .number.precision(.fractionLength(0)))s · \(session.misses) wrong")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button(action: finish) {
                Text("Good morning")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    // MARK: - Actions

    private var isLocked: Bool { session.isLocked(at: now) }

    private var canSnooze: Bool {
        context.alarm.snoozeMinutes > 0 && snoozesUsed < context.alarm.maxSnoozes
    }

    private func columns(for count: Int) -> [GridItem] {
        let columnCount = count == 3 ? 3 : (count <= 4 ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    private func tileState(for character: BrainrotCharacter) -> CreatureTile.Highlight {
        guard let feedback, feedback.characterID == character.id else { return .idle }
        return feedback.isCorrect ? .correct : .wrong
    }

    private func startRound() async {
        guard let round = session.currentRound else { return }
        await audio.startRinging(round.answer)
    }

    private func tap(_ character: BrainrotCharacter) {
        let outcome = session.select(character.id, now: Date())
        switch outcome {
        case .ignored:
            return

        case .correct:
            haptic(.success)
            feedback = Feedback(characterID: character.id, isCorrect: true)
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                feedback = nil
                await startRound()
            }

        case .solved:
            haptic(.success)
            feedback = Feedback(characterID: character.id, isCorrect: true)
            solvedAt = Date()
            audio.stop()
            recordWake()

        case .wrong:
            haptic(.error)
            feedback = Feedback(characterID: character.id, isCorrect: false)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                feedback = nil
            }
        }
    }

    private func snooze() {
        snoozesUsed += 1
        audio.stop()
        Task {
            if !context.isRehearsal {
                await SnoozeScheduler.schedule(alarm: context.alarm,
                                               minutes: context.alarm.snoozeMinutes)
            }
            router.clear()
            dismiss()
        }
    }

    private func finish() {
        audio.stop()
        audio.deactivateSession()
        router.clear()
        dismiss()
    }

    private func recordWake() {
        guard !context.isRehearsal else { return }
        guard let character = session.rounds.last?.answer, let solvedAt else { return }
        store.record(WakeRecord(
            date: solvedAt,
            alarmID: context.alarm.id,
            characterID: character.id,
            difficulty: context.alarm.difficulty,
            secondsToDismiss: solvedAt.timeIntervalSince(context.firedAt),
            misses: session.misses,
            snoozes: snoozesUsed))
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard context.alarm.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
