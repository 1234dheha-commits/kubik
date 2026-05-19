import SwiftUI

struct BlockGameView: View {
    @ObservedObject var game: BlockGame
    var onExit: () -> Void

    @State private var boardOrigin: CGPoint = .zero
    @State private var boardSide: CGFloat = 1
    @State private var dragIndex: Int?
    @State private var dragPoint: CGPoint = .zero      // finger, "root" space

    private var cell: CGFloat { boardSide / CGFloat(BlockGame.size) }
    private func inset(_ s: CGFloat) -> CGFloat { s * 0.07 }

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

                if let di = dragIndex, di < game.tray.count,
                   let piece = game.tray[di] {
                    floating(piece)
                }
            }
            .coordinateSpace(name: "root")
            .overlay { if game.gameOver { gameOverOverlay } }
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
                Text("Счёт").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text("\(game.score)")
                    .font(.system(size: 24, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("Рекорд").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text("\(max(game.best, game.score))")
                    .font(.system(size: 24, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.accent)
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

    // MARK: Board (fixed square)

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
            ForEach(0..<3, id: \.self) { i in
                trayCell(i)
            }
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

    // MARK: Floating piece (follows the finger, lifted above it)

    private func floating(_ piece: Piece) -> some View {
        let w = CGFloat(piece.cols) * cell
        let h = CGFloat(piece.rows) * cell
        return pieceShape(piece, cell: cell)
            .frame(width: w, height: h, alignment: .topLeading)
            .position(x: dragPoint.x, y: dragPoint.y - h / 2 - cell * 0.6)
            .allowsHitTesting(false)
    }

    /// Board base cell the floating piece currently targets, or nil.
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
                Text("Игра окончена")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text("Счёт \(game.score)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text("Рекорд \(game.best)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Button { game.newGame() } label: {
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
