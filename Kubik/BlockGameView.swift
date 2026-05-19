import SwiftUI
import UIKit

enum Haptics {
    private static var on: Bool {
        (UserDefaults.standard.object(forKey: "kubik.haptics") as? Bool) ?? true
    }
    static func tap()  { if on { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func clr()  { if on { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
    static func over() { if on { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
}

struct BlockGameView: View {
    @ObservedObject var game: BlockGame
    var onExit: () -> Void

    @State private var boardOrigin: CGPoint = .zero
    @State private var boardSide: CGFloat = 1
    @State private var dragIndex: Int?
    @State private var dragPoint: CGPoint = .zero
    @State private var popup: Gain?
    @State private var popupShown = false

    private var cell: CGFloat { boardSide / CGFloat(BlockGame.size) }
    private func inset(_ s: CGFloat) -> CGFloat { s * 0.07 }

    private func timeStr(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        GeometryReader { geo in
            let side = max(180,
                           min(geo.size.width - 32, geo.size.height - 300))
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    topBar
                    board(side: side)
                    Spacer(minLength: 0)
                    tray
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if let p = popup {
                    Text("+\(p.amount)")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .offset(y: popupShown ? -130 : -70)
                        .opacity(popupShown ? 0 : 1)
                        .allowsHitTesting(false)
                }

                if let di = dragIndex, di < game.tray.count,
                   let piece = game.tray[di] {
                    floating(piece)
                }
            }
            .coordinateSpace(name: "root")
            .overlay { if game.gameOver { gameOverOverlay } }
        }
        .onChange(of: game.gain) { _, g in
            guard let g else { return }
            popup = g
            popupShown = false
            withAnimation(.easeOut(duration: 0.7)) { popupShown = true }
            if g.amount >= 16 { Haptics.clr() } else { Haptics.tap() }
        }
        .onChange(of: game.gameOver) { _, over in
            if over { Haptics.over() }
        }
    }

    // MARK: Top bar

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
            VStack(spacing: 1) {
                Text(game.mode == .timed
                     ? timeStr(game.timeLeft) : "\(game.score)")
                    .font(.system(size: 26, weight: .heavy).monospacedDigit())
                    .foregroundStyle(game.mode == .timed && game.timeLeft <= 15
                                     ? Color.red : Theme.text)
                Text(game.mode == .timed
                     ? "Счёт \(game.score)" : game.mode.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("\(max(game.best, game.score))")
                    .font(.system(size: 26, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                Text("Рекорд").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { game.restart() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40)
                    .background(Theme.panel, in: Circle())
            }
        }
    }

    // MARK: Board

    private func board(side: CGFloat) -> some View {
        let cs = side / CGFloat(BlockGame.size)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<BlockGame.size, id: \.self) { r in
                ForEach(0..<BlockGame.size, id: \.self) { c in
                    slot(game.grid[r][c], size: cs)
                        .frame(width: cs, height: cs)
                        .offset(x: CGFloat(c) * cs, y: CGFloat(r) * cs)
                }
            }
            if let di = dragIndex, di < game.tray.count,
               let piece = game.tray[di],
               let base = targetBase(piece) {
                ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, p in
                    RoundedRectangle(cornerRadius: cs * 0.2, style: .continuous)
                        .fill(piece.color.opacity(0.45))
                        .padding(inset(cs))
                        .frame(width: cs, height: cs)
                        .offset(x: CGFloat(base.c + p.c) * cs,
                                y: CGFloat(base.r + p.r) * cs)
                }
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.16), value: game.grid)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.panel)
                .padding(-8)
        )
        .background(
            GeometryReader { gg -> Color in
                let f = gg.frame(in: .named("root"))
                DispatchQueue.main.async {
                    boardOrigin = CGPoint(x: f.minX, y: f.minY)
                    boardSide = f.width
                }
                return Color.clear
            }
        )
        .frame(maxWidth: .infinity)
    }

    private func slot(_ idx: Int?, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(idx == nil
                  ? Theme.empty
                  : Theme.palette[idx! % Theme.palette.count])
            .padding(inset(size))
    }

    // MARK: Tray

    private var tray: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in trayCell(i) }
        }
        .frame(height: 104)
    }

    @ViewBuilder
    private func trayCell(_ i: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.panel)
            if i < game.tray.count, let piece = game.tray[i],
               dragIndex != i {
                pieceShape(piece, cell: 24)
                    .gesture(
                        DragGesture(minimumDistance: 2,
                                    coordinateSpace: .named("root"))
                            .onChanged { v in
                                dragIndex = i
                                dragPoint = v.location
                            }
                            .onEnded { v in
                                dragPoint = v.location
                                if let p = game.tray[i],
                                   let base = targetBase(p) {
                                    _ = game.place(trayIndex: i, at: base)
                                }
                                dragIndex = nil
                            }
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    // MARK: Floating piece

    private func floating(_ piece: Piece) -> some View {
        let w = CGFloat(piece.cols) * cell
        let h = CGFloat(piece.rows) * cell
        return pieceShape(piece, cell: cell)
            .frame(width: w, height: h, alignment: .topLeading)
            .scaleEffect(1.06)
            .position(x: dragPoint.x, y: dragPoint.y - h / 2 - cell * 0.6)
            .allowsHitTesting(false)
    }

    private func targetBase(_ piece: Piece) -> GridPoint? {
        guard boardSide > 1 else { return nil }
        let w = CGFloat(piece.cols) * cell
        let h = CGFloat(piece.rows) * cell
        let topLeftX = dragPoint.x - w / 2
        let topLeftY = dragPoint.y - h - cell * 0.6
        let c = Int(((topLeftX - boardOrigin.x) / cell).rounded())
        let r = Int(((topLeftY - boardOrigin.y) / cell).rounded())
        let base = GridPoint(r: r, c: c)
        return game.canPlace(piece, at: base) ? base : nil
    }

    private func pieceShape(_ piece: Piece, cell pc: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, p in
                RoundedRectangle(cornerRadius: pc * 0.22, style: .continuous)
                    .fill(piece.color)
                    .frame(width: pc, height: pc)
                    .padding(pc * 0.06)
                    .offset(x: CGFloat(p.c) * pc, y: CGFloat(p.r) * pc)
            }
        }
        .frame(width: CGFloat(piece.cols) * pc,
               height: CGFloat(piece.rows) * pc,
               alignment: .topLeading)
    }

    // MARK: Game over

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(game.mode == .timed ? "Время вышло" : "Игра окончена")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text("Счёт \(game.score)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text("Рекорд \(game.best) · \(game.mode.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Button { game.restart() } label: {
                    Text("Ещё раз")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
