import SwiftUI

struct GridPoint: Hashable {
    var r: Int
    var c: Int
}

/// A draggable block shape (polyomino), normalised so min row/col is 0.
struct Piece: Identifiable {
    let id = UUID()
    let cells: [GridPoint]
    let colorIndex: Int
    var color: Color { Theme.palette[colorIndex % Theme.palette.count] }
    var rows: Int { (cells.map { $0.r }.max() ?? 0) + 1 }
    var cols: Int { (cells.map { $0.c }.max() ?? 0) + 1 }
}

enum Shapes {
    static let all: [[GridPoint]] = {
        func p(_ a: [(Int, Int)]) -> [GridPoint] {
            a.map { GridPoint(r: $0.0, c: $0.1) }
        }
        return [
            p([(0,0)]),
            p([(0,0),(0,1)]),
            p([(0,0),(1,0)]),
            p([(0,0),(0,1),(0,2)]),
            p([(0,0),(1,0),(2,0)]),
            p([(0,0),(0,1),(0,2),(0,3)]),
            p([(0,0),(1,0),(2,0),(3,0)]),
            p([(0,0),(0,1),(1,0),(1,1)]),
            p([(0,0),(1,0),(1,1)]),
            p([(0,1),(1,0),(1,1)]),
            p([(0,0),(0,1),(1,1)]),
            p([(0,0),(0,1),(1,0)]),
            p([(0,0),(1,0),(2,0),(2,1)]),
            p([(0,1),(1,1),(2,0),(2,1)]),
            p([(0,0),(0,1),(0,2),(1,1)]),
            p([(0,1),(1,0),(1,1),(1,2)]),
            p([(0,0),(0,1),(1,1),(1,2)]),
            p([(0,1),(0,2),(1,0),(1,1)]),
            p([(0,0),(0,1),(0,2),(1,0),(1,1),(1,2)])
        ]
    }()
}

enum GameMode: String, CaseIterable, Identifiable {
    case classic, timed, zen
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Классика"
        case .timed:   return "На время"
        case .zen:     return "Зен"
        }
    }
    var subtitle: String {
        switch self {
        case .classic: return "Пока не застрянешь"
        case .timed:   return "3 минуты на максимум"
        case .zen:     return "Без проигрыша"
        }
    }
    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3.fill"
        case .timed:   return "timer"
        case .zen:     return "leaf.fill"
        }
    }
    var bestKey: String { "kubik.best.\(rawValue)" }
}

struct Gain: Equatable {
    let id: Int
    let amount: Int
}

final class BlockGame: ObservableObject {
    static let size = 8

    @Published var grid: [[Int?]]
    @Published var tray: [Piece?] = [nil, nil, nil]
    @Published var score = 0
    @Published var best = 0
    @Published var gameOver = false
    @Published var mode: GameMode = .classic
    @Published var timeLeft = 0
    @Published var gain: Gain?

    private var timer: Timer?
    private var gainSeq = 0

    static func empty() -> [[Int?]] {
        Array(repeating: Array(repeating: nil, count: size), count: size)
    }

    init() {
        grid = Self.empty()
        start(.classic)
    }

    func start(_ m: GameMode) {
        timer?.invalidate(); timer = nil
        mode = m
        grid = Self.empty()
        score = 0
        gain = nil
        gameOver = false
        tray = [nil, nil, nil]
        best = UserDefaults.standard.integer(forKey: m.bestKey)
        refill()
        if m == .timed {
            timeLeft = 180
            timer = Timer.scheduledTimer(withTimeInterval: 1,
                                         repeats: true) { [weak self] _ in
                guard let self, !self.gameOver else { return }
                if self.timeLeft > 0 { self.timeLeft -= 1 }
                if self.timeLeft <= 0 { self.endGame() }
            }
        }
    }

    func restart() { start(mode) }

    private func randomPiece() -> Piece {
        Piece(cells: Shapes.all.randomElement()!,
              colorIndex: Int.random(in: 0..<Theme.palette.count))
    }

    private func refill() {
        if tray.allSatisfy({ $0 == nil }) {
            tray = [randomPiece(), randomPiece(), randomPiece()]
        }
        checkState()
    }

    private func addScore(_ n: Int) {
        score += n
        gainSeq += 1
        gain = Gain(id: gainSeq, amount: n)
    }

    func canPlace(_ piece: Piece, at base: GridPoint) -> Bool {
        for cell in piece.cells {
            let r = base.r + cell.r
            let c = base.c + cell.c
            if r < 0 || r >= Self.size || c < 0 || c >= Self.size { return false }
            if grid[r][c] != nil { return false }
        }
        return true
    }

    func canPlaceAnywhere(_ piece: Piece) -> Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size where canPlace(piece, at: GridPoint(r: r, c: c)) {
                return true
            }
        }
        return false
    }

    @discardableResult
    func place(trayIndex: Int, at base: GridPoint) -> Bool {
        guard tray.indices.contains(trayIndex),
              let piece = tray[trayIndex],
              !gameOver,
              canPlace(piece, at: base) else { return false }
        for cell in piece.cells {
            grid[base.r + cell.r][base.c + cell.c] = piece.colorIndex
        }
        addScore(piece.cells.count)
        tray[trayIndex] = nil
        clearLines()
        if tray.allSatisfy({ $0 == nil }) {
            tray = [randomPiece(), randomPiece(), randomPiece()]
        }
        checkState()
        return true
    }

    private func clearLines() {
        var fullRows: [Int] = []
        var fullCols: [Int] = []
        for r in 0..<Self.size where grid[r].allSatisfy({ $0 != nil }) {
            fullRows.append(r)
        }
        for c in 0..<Self.size {
            var full = true
            for r in 0..<Self.size where grid[r][c] == nil { full = false; break }
            if full { fullCols.append(c) }
        }
        let lines = fullRows.count + fullCols.count
        guard lines > 0 else { return }
        for r in fullRows { for c in 0..<Self.size { grid[r][c] = nil } }
        for c in fullCols { for r in 0..<Self.size { grid[r][c] = nil } }
        let cells = lines * Self.size
        addScore(cells + lines * 10 + (lines - 1) * 10)
    }

    private func checkState() {
        let pieces = tray.compactMap { $0 }
        guard !pieces.isEmpty else { return }
        if pieces.contains(where: { canPlaceAnywhere($0) }) { return }
        if mode == .zen {
            // Relief instead of losing: clear some random filled cells.
            var filled: [GridPoint] = []
            for r in 0..<Self.size {
                for c in 0..<Self.size where grid[r][c] != nil {
                    filled.append(GridPoint(r: r, c: c))
                }
            }
            filled.shuffle()
            for g in filled.prefix(16) { grid[g.r][g.c] = nil }
            if !pieces.contains(where: { canPlaceAnywhere($0) }) {
                grid = Self.empty()
            }
        } else {
            endGame()
        }
    }

    private func endGame() {
        gameOver = true
        timer?.invalidate(); timer = nil
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: mode.bestKey)
        }
    }
}
