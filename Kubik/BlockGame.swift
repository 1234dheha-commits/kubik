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

final class BlockGame: ObservableObject {
    static let size = 8

    @Published var grid: [[Int?]]
    @Published var tray: [Piece?] = [nil, nil, nil]
    @Published var score = 0
    @Published var best = UserDefaults.standard.integer(forKey: "kubik.best")
    @Published var gameOver = false

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.size),
                     count: Self.size)
        refill()
    }

    func newGame() {
        grid = Array(repeating: Array(repeating: nil, count: Self.size),
                     count: Self.size)
        score = 0
        gameOver = false
        tray = [nil, nil, nil]
        refill()
    }

    private func randomPiece() -> Piece {
        Piece(cells: Shapes.all.randomElement()!,
              colorIndex: Int.random(in: 0..<Theme.palette.count))
    }

    private func refill() {
        if tray.allSatisfy({ $0 == nil }) {
            tray = [randomPiece(), randomPiece(), randomPiece()]
        }
        checkGameOver()
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
              canPlace(piece, at: base) else { return false }
        for cell in piece.cells {
            grid[base.r + cell.r][base.c + cell.c] = piece.colorIndex
        }
        score += piece.cells.count
        tray[trayIndex] = nil
        clearLines()
        if tray.allSatisfy({ $0 == nil }) {
            tray = [randomPiece(), randomPiece(), randomPiece()]
        }
        checkGameOver()
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
        let cells = (fullRows.count + fullCols.count) * Self.size
        // placed-cell points already added; lines give a fat bonus + combo.
        score += cells + lines * 10 + (lines - 1) * 10
    }

    private func checkGameOver() {
        let pieces = tray.compactMap { $0 }
        guard !pieces.isEmpty else { gameOver = false; return }
        if pieces.contains(where: { canPlaceAnywhere($0) }) {
            gameOver = false
        } else {
            gameOver = true
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: "kubik.best")
            }
        }
    }
}
