import SwiftUI

struct RootView: View {
    private enum Screen { case home, modes, block, durak }
    @State private var screen: Screen = .home
    @StateObject private var blockGame = BlockGame()
    @StateObject private var durakGame = DurakGame()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch screen {
            case .home:  home
            case .modes: modeMenu
            case .block:
                BlockGameView(game: blockGame) { screen = .modes }
                    .transition(.opacity)
            case .durak:
                DurakView(game: durakGame) { screen = .home }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screen)
    }

    // MARK: Home

    private var home: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                Text("KUBIK")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .tracking(4)
                Text("Блоки и не только")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 36)

            VStack(spacing: 14) {
                card(title: "Блоки", subtitle: "3 режима",
                     icon: "square.grid.3x3.fill", enabled: true) {
                    screen = .modes
                }
                card(title: "Дурак", subtitle: "Против бота",
                     icon: "suit.spade.fill", enabled: true) {
                    durakGame.newGame()
                    screen = .durak
                }
                card(title: "Ещё режимы", subtitle: "В разработке",
                     icon: "sparkles", enabled: false) {}
            }
            .padding(.horizontal, 26)

            Spacer()
            Text("Без интернета и аккаунтов")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 18)
        }
    }

    // MARK: Mode menu

    private var modeMenu: some View {
        VStack(spacing: 0) {
            HStack {
                Button { screen = .home } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 40, height: 40)
                        .background(Theme.panel, in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 12)

            Spacer()
            Text("Блоки")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 24)
            VStack(spacing: 14) {
                ForEach(GameMode.allCases) { m in
                    card(title: m.title, subtitle: m.subtitle,
                         icon: m.icon, enabled: true) {
                        blockGame.start(m)
                        screen = .block
                    }
                }
            }
            .padding(.horizontal, 26)
            Spacer()
            Spacer()
        }
    }

    // MARK: Card

    private func card(title: String, subtitle: String, icon: String,
                      enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(enabled ? Theme.accent : Theme.muted)
                    .frame(width: 52, height: 52)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(enabled ? Theme.text : Theme.muted)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: enabled ? "chevron.right" : "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .background(Theme.panel,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(enabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
