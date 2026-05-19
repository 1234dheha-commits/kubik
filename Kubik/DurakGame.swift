import SwiftUI

enum Suit: Int, CaseIterable {
    case spades, hearts, diamonds, clubs
    var sym: String { ["♠", "♥", "♦", "♣"][rawValue] }
    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct Card: Identifiable, Equatable {
    let rank: Int          // 6...14 (J11 Q12 K13 A14)
    let suit: Suit
    var id: Int { rank * 10 + suit.rawValue }
    var label: String { ["6","7","8","9","10","J","Q","K","A"][rank - 6] }
}

struct Pair: Identifiable {
    let id = UUID()
    var attack: Card
    var defense: Card?
}

/// Offline 1 vs 1 "Durak" (podkidnoy) against a simple bot.
final class DurakGame: ObservableObject {
    @Published var human: [Card] = []
    @Published var bot: [Card] = []
    @Published var table: [Pair] = []
    @Published var trump: Suit = .spades
    @Published var trumpCard: Card?
    @Published var deckCount = 0
    @Published var humanAttacking = true
    @Published var humanIsDefender = false
    @Published var message = ""
    @Published var over = false
    @Published var humanWon = false

    private var deck: [Card] = []

    func newGame() {
        deck = []
        for s in Suit.allCases { for r in 6...14 { deck.append(Card(rank: r, suit: s)) } }
        deck.shuffle()
        trumpCard = deck.first
        trump = deck.first?.suit ?? .spades
        // trump card sits at the bottom (drawn last)
        if let t = trumpCard { deck.removeFirst(); deck.append(t) }
        human = []; bot = []; table = []; over = false; humanWon = false
        for _ in 0..<6 { drawTo(&human); drawTo(&bot) }
        sortHand()
        // lowest trump starts
        let hMin = human.filter { $0.suit == trump }.map { $0.rank }.min()
        let bMin = bot.filter { $0.suit == trump }.map { $0.rank }.min()
        humanAttacking = (hMin ?? 99) <= (bMin ?? 99)
        humanIsDefender = !humanAttacking
        deckCount = deck.count
        message = humanAttacking ? "Ваш ход. Атакуйте." : "Соперник атакует."
        if !humanAttacking { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.botAttack() } }
    }

    private func drawTo(_ hand: inout [Card]) {
        if !deck.isEmpty { hand.append(deck.removeFirst()) }
    }
    private func sortHand() {
        human.sort { ($0.suit == trump ? 1 : 0, $0.rank) < ($1.suit == trump ? 1 : 0, $1.rank) }
    }

    func beats(_ d: Card, _ a: Card) -> Bool {
        if d.suit == a.suit { return d.rank > a.rank }
        return d.suit == trump && a.suit != trump
    }

    private var tableRanks: Set<Int> {
        var s = Set<Int>()
        for p in table { s.insert(p.attack.rank); if let d = p.defense { s.insert(d.rank) } }
        return s
    }
    private var openPair: Pair? { table.first(where: { $0.defense == nil }) }
    private var maxAttacks: Int { min(6, (humanAttacking ? human.count : bot.count) + table.count) }

    // MARK: Human as attacker

    func humanPlay(_ c: Card) {
        if humanIsDefender { humanDefendWith(c); return }
        guard humanAttacking, !over else { return }
        if openPair != nil { return }                       // wait: bot must answer
        if !table.isEmpty && !tableRanks.contains(c.rank) {
            message = "Можно подкинуть только тот же номинал."
            return
        }
        if table.count >= maxAttacks { message = "Больше нельзя."; return }
        human.removeAll { $0.id == c.id }
        table.append(Pair(attack: c))
        message = "Соперник защищается."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.botDefend() }
    }

    /// Attacker says "done" (Бито) once everything is covered.
    func humanDone() {
        guard humanAttacking, !over, !table.isEmpty,
              table.allSatisfy({ $0.defense != nil }) else { return }
        endBout(defenderTook: false)
    }

    // MARK: Human as defender

    private func humanDefendWith(_ c: Card) {
        guard humanIsDefender, !over, let p = openPair else { return }
        guard beats(c, p.attack) else {
            message = "Эта карта не бьёт."
            return
        }
        if let i = table.firstIndex(where: { $0.id == p.id }) {
            table[i].defense = c
            human.removeAll { $0.id == c.id }
        }
        if table.allSatisfy({ $0.defense != nil }) {
            message = "Отбито. Соперник может подкинуть."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.botAttack(adding: true) }
        }
    }

    func humanTake() {
        guard humanIsDefender, !over, !table.isEmpty else { return }
        // bot may throw in more before the take
        botThrowInBeforeTake()
        for p in table { human.append(p.attack); if let d = p.defense { human.append(d) } }
        table = []
        sortHand()
        message = "Вы взяли карты."
        finishBout(humanWasDefender: true, tookCards: true)
    }

    // MARK: Bot

    private func botDefend() {
        guard !over, let p = openPair else { return }
        let cands = bot.filter { beats($0, p.attack) }
            .sorted { ($0.suit == trump ? 1 : 0, $0.rank) < ($1.suit == trump ? 1 : 0, $1.rank) }
        if let d = cands.first, d.rank - p.attack.rank < 7 || p.attack.suit == trump {
            if let i = table.firstIndex(where: { $0.id == p.id }) {
                table[i].defense = d
                bot.removeAll { $0.id == d.id }
            }
            message = "Соперник отбился. Ваш ход: подкиньте или Бито."
        } else {
            for p in table { bot.append(p.attack); if let dd = p.defense { bot.append(dd) } }
            table = []
            message = "Соперник взял карты."
            finishBout(humanWasDefender: false, tookCards: true)
        }
    }

    private func botAttack(adding: Bool = false) {
        guard !over else { return }
        if adding {
            // bot (attacker) may throw in matching ranks
            let ranks = tableRanks
            let extra = bot.filter { ranks.contains($0.rank) }
                .sorted { $0.rank < $1.rank }
            if let c = extra.first, table.count < min(6, human.count + table.count) {
                bot.removeAll { $0.id == c.id }
                table.append(Pair(attack: c))
                message = "Соперник подкинул \(c.label)\(c.suit.sym). Защищайтесь или Взять."
                return
            }
            endBout(defenderTook: false)
            return
        }
        // fresh attack
        let c = bot.sorted { ($0.suit == trump ? 1 : 0, $0.rank) < ($1.suit == trump ? 1 : 0, $1.rank) }.first
        guard let card = c else { checkEnd(); return }
        bot.removeAll { $0.id == card.id }
        table.append(Pair(attack: card))
        humanIsDefender = true
        message = "Соперник атакует \(card.label)\(card.suit.sym). Защищайтесь или Взять."
    }

    private func botThrowInBeforeTake() {
        let ranks = tableRanks
        let extra = bot.filter { ranks.contains($0.rank) }.sorted { $0.rank < $1.rank }
        for c in extra where table.count < 6 {
            bot.removeAll { $0.id == c.id }
            table.append(Pair(attack: c))
        }
    }

    // MARK: Bout end / refill

    private func endBout(defenderTook: Bool) {
        table = []
        finishBout(humanWasDefender: humanIsDefender, tookCards: defenderTook)
    }

    private func finishBout(humanWasDefender: Bool, tookCards: Bool) {
        // refill: attacker first then defender
        let attackerIsHuman = !( humanWasDefender )
        func fill(_ humanSide: Bool) {
            if humanSide { while human.count < 6 && !deck.isEmpty { drawTo(&human) } }
            else { while bot.count < 6 && !deck.isEmpty { drawTo(&bot) } }
        }
        fill(attackerIsHuman); fill(!attackerIsHuman)
        sortHand()
        deckCount = deck.count
        if checkEnd() { return }
        // who attacks next: if defender took, attacker keeps; else defender attacks
        if tookCards {
            humanAttacking = !humanWasDefender
        } else {
            humanAttacking = humanWasDefender
        }
        humanIsDefender = !humanAttacking
        if humanAttacking {
            message = "Ваш ход. Атакуйте."
        } else {
            message = "Соперник атакует."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.botAttack() }
        }
    }

    @discardableResult
    private func checkEnd() -> Bool {
        guard deck.isEmpty else { return false }
        if human.isEmpty && bot.isEmpty {
            over = true; humanWon = true; message = "Ничья."
            return true
        }
        if human.isEmpty { over = true; humanWon = true; message = "Вы выиграли!"; return true }
        if bot.isEmpty { over = true; humanWon = false; message = "Вы проиграли. Дурак."; return true }
        return false
    }
}
