import SwiftUI

struct DurakView: View {
    @ObservedObject var game: DurakGame
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                topBar
                botRow
                Spacer(minLength: 0)
                tableRow
                Spacer(minLength: 0)
                statusRow
                handRow
                actionRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if game.over { overOverlay }
        }
        .onAppear { if game.human.isEmpty { game.newGame() } }
    }

    private var topBar: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40)
                    .background(Theme.panel, in: Circle())
            }
            Spacer()
            HStack(spacing: 6) {
                Text("Козырь")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text(game.trump.sym)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(game.trump.isRed ? .red : Theme.text)
                Text("· колода \(game.deckCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { game.newGame() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40)
                    .background(Theme.panel, in: Circle())
            }
        }
    }

    private var botRow: some View {
        HStack(spacing: -16) {
            ForEach(game.bot) { c in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accent.opacity(0.85))
                    .frame(width: 40, height: 58)
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .stroke(Theme.bg, lineWidth: 2))
                    .id(c.id)
            }
        }
        .frame(height: 60)
    }

    private var tableRow: some View {
        HStack(spacing: 10) {
            ForEach(game.table) { p in
                ZStack(alignment: .topLeading) {
                    cardView(p.attack)
                    if let d = p.defense {
                        cardView(d).offset(x: 16, y: 22)
                    }
                }
                .frame(width: 70, height: 118)
            }
        }
        .frame(minHeight: 120)
        .animation(.easeInOut(duration: 0.2), value: game.table.count)
    }

    private var statusRow: some View {
        Text(game.message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
    }

    private var handRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.human) { c in
                    Button { game.humanPlay(c) } label: { cardView(c) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 96)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if game.humanIsDefender {
                Button { game.humanTake() } label: {
                    Text("Взять")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.red.opacity(0.85),
                                    in: RoundedRectangle(cornerRadius: 13))
                }
            } else {
                Button { game.humanDone() } label: {
                    Text("Бито")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.accent,
                                    in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
    }

    private func cardView(_ c: Card) -> some View {
        VStack(spacing: 2) {
            Text(c.label).font(.system(size: 19, weight: .heavy))
            Text(c.suit.sym).font(.system(size: 17, weight: .bold))
        }
        .foregroundStyle(c.suit.isRed ? Color.red : Color.black)
        .frame(width: 64, height: 92)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10,
                                                      style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(c.suit == game.trump ? Theme.accent : .clear, lineWidth: 2))
    }

    private var overOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(game.humanWon ? "Победа" : "Вы дурак")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text(game.message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Button { game.newGame() } label: {
                    Text("Ещё раз")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                Button(action: onExit) {
                    Text("В меню")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(26)
            .background(Theme.panel,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(40)
        }
    }
}
