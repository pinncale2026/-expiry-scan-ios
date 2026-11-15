import Foundation

struct Item: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var code: String = ""
    var name: String = ""
    var exp: Date = Date()
    var qty: Int = 1
    var addedAt: Date = Date()
}

final class Store: ObservableObject {

    @Published var items: [Item] = []

    private let key = "dsh.expiry.ios.v1"
    private let cal = Calendar.current

    init() { load() }

    // MARK: - persistence

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([Item].self, from: data) else { return }
        items = arr
    }

    func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - mutation

    /// Adds a new row, or bumps the quantity when the same code+name+expiry is scanned again.
    @discardableResult
    func add(_ p: Parsed) -> (item: Item, isDuplicate: Bool) {
        if let i = items.firstIndex(where: {
            $0.code == p.code && $0.name == p.name && abs($0.exp.timeIntervalSince(p.exp)) < 1
        }) {
            items[i].qty = max(1, items[i].qty) + 1
            save()
            return (items[i], true)
        }
        var it = Item()
        it.code = p.code
        it.name = p.name
        it.exp = p.exp
        it.qty = 1
        items.append(it)
        save()
        return (it, false)
    }

    func bump(_ id: UUID, by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let next = items[i].qty + delta
        if next <= 0 {
            items.remove(at: i)
        } else {
            items[i].qty = next
        }
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    // MARK: - queries

    func items(on day: Date) -> [Item] {
        items.filter { cal.isDate($0.exp, inSameDayAs: day) }
            .sorted { $0.exp < $1.exp }
    }

    func qty(_ arr: [Item]) -> Int {
        arr.reduce(0) { $0 + max(1, $1.qty) }
    }

    func expired() -> [Item] {
        items.filter { $0.exp < Date() }
    }

    func tomorrow() -> Date {
        cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    func yesterday() -> Date {
        cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    /// counts per day for the next 7 days (today first)
    func weekCounts() -> [(day: Date, count: Int)] {
        var out: [(day: Date, count: Int)] = []
        let today = cal.startOfDay(for: Date())
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            out.append((day: d, count: qty(items(on: d))))
        }
        return out
    }
}
