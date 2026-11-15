import Foundation
import SwiftUI

enum Fmt {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f
    }()
    static let dayLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
    static let ink = Color(hex: 0x0F1115)
    static let card = Color(hex: 0x171A21)
    static let line = Color(hex: 0x2A2F3A)
    static let dim = Color(hex: 0x9AA3B2)
    static let good = Color(hex: 0x37D67A)
    static let warn = Color(hex: 0xFFB020)
    static let bad = Color(hex: 0xFF5C5C)
    static let accent = Color(hex: 0x4DA3FF)
}

struct Pill {
    let text: String
    let color: Color
}

struct ContentView: View {

    @EnvironmentObject var store: Store

    @State private var showScanner = false
    @State private var showPicker = false
    @State private var manual = ""
    @State private var toast: String?
    @State private var showAll = false
    @State private var confirmClear = false

    private var todayItems: [Item] { store.items(on: Date()) }
    private var tomorrowItems: [Item] { store.items(on: store.tomorrow()) }
    private var yesterdayItems: [Item] { store.items(on: store.yesterday()) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    header
                    summaryCard
                    chartCard
                    listCard(title: "今天到期 / 已过期",
                             hint: todayItems.isEmpty ? "" : "\(todayItems.count) 行 / \(store.qty(todayItems)) 件",
                             items: todayItems,
                             empty: "今天没有到期的产品",
                             pill: pillForToday)
                    listCard(title: "次日到期",
                             hint: tomorrowItems.isEmpty ? "" : "\(tomorrowItems.count) 行 / \(store.qty(tomorrowItems)) 件",
                             items: tomorrowItems,
                             empty: "明天没有到期的产品",
                             pill: pillForTomorrow)
                    listCard(title: "昨日到期",
                             hint: yesterdayItems.isEmpty ? "" : "\(yesterdayItems.count) 行 / \(store.qty(yesterdayItems)) 件",
                             items: yesterdayItems,
                             empty: "昨天没有到期的产品",
                             pill: pillForYesterday)
                    manualCard
                    allCard
                    noteCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }

            scanButton

            if let t = toast {
                Text(t)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x252A35))
                    .cornerRadius(12)
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showScanner) {
            ScannerView(onCode: { code in
                showScanner = false
                handleScan(code)
            }, onClose: {
                showScanner = false
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPicker) {
            PhotoScannerView { text in
                showPicker = false
                if let t = text {
                    handleScan(t)
                } else {
                    show("没识别到二维码，试试重拍或裁剪")
                }
            }
        }
        .alert("清空全部记录？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                store.clear()
                show("已清空")
            }
        } message: {
            Text("共 \(store.qty(store.items)) 件，清空后不可恢复")
        }
    }

    // MARK: - sections

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.good).frame(width: 8, height: 8)
            Text("效期扫码").font(.system(size: 19, weight: .bold))
            Spacer()
        }
        .padding(.top, 4)
    }

    private var summaryCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日到期（件数）").font(.system(size: 13)).foregroundColor(.dim)
                Text("\(store.qty(todayItems))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(summaryColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("库存总件数").font(.system(size: 13)).foregroundColor(.dim)
                Text("\(store.qty(store.items))").font(.system(size: 26, weight: .bold))
                if !store.expired().isEmpty {
                    Text("已过期 \(store.qty(store.expired())) 件")
                        .font(.system(size: 12)).foregroundColor(.dim)
                }
            }
        }
        .cardStyle()
    }

    private var summaryColor: Color {
        if todayItems.isEmpty { return .good }
        let hasExpired = todayItems.contains { $0.exp < Date() }
        return hasExpired ? .bad : .warn
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("未来 7 天到期件数").font(.system(size: 13)).foregroundColor(.dim)
                Spacer()
                let total = store.weekCounts().reduce(0) { $0 + $1.count }
                Text(total > 0 ? "\(total) 件待处理" : "暂无到期")
                    .font(.system(size: 12)).foregroundColor(.dim)
            }
            WeekChart(data: store.weekCounts())
                .frame(height: 150)
        }
        .cardStyle()
    }

    private func listCard(title: String,
                          hint: String,
                          items: [Item],
                          empty: String,
                          pill: @escaping (Item) -> Pill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundColor(.dim)
                Spacer()
                Text(hint).font(.system(size: 12)).foregroundColor(.dim)
            }
            if items.isEmpty {
                Text(empty)
                    .font(.system(size: 13))
                    .foregroundColor(.dim)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    ItemRow(item: item, pill: pill(item))
                    if item.id != items.last?.id {
                        Divider().background(Color.line)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手动录入（也可粘贴二维码原文）")
                .font(.system(size: 13)).foregroundColor(.dim)

            TextField("例如 88811300 香辣鸡翅 2026-11-11 23:59", text: $manual)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color(hex: 0x0D0F14))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Button {
                    addManual()
                } label: {
                    Text("添加").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())

                Button {
                    showPicker = true
                } label: {
                    Text("从相册识别").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .cardStyle()
    }

    private var allCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showAll.toggle() }
            } label: {
                HStack {
                    Text("全部记录（\(store.qty(store.items)) 件）")
                        .font(.system(size: 13)).foregroundColor(.dim)
                    Spacer()
                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundColor(.dim)
                }
            }

            if showAll {
                let sorted = store.items.sorted { $0.exp < $1.exp }
                if sorted.isEmpty {
                    Text("还没有记录，点下面「扫码」开始")
                        .font(.system(size: 13)).foregroundColor(.dim)
                } else {
                    ForEach(sorted) { item in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .lineLimit(1)
                                Text(subtitle(item))
                                    .font(.system(size: 11)).foregroundColor(.dim).lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text("×\(max(1, item.qty))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.accent)
                            Button { store.bump(item.id, by: 1) } label: {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            }
                            .buttonStyle(MiniButtonStyle())
                            Button { store.bump(item.id, by: -1) } label: {
                                Image(systemName: "minus").font(.system(size: 12, weight: .bold))
                            }
                            .buttonStyle(MiniButtonStyle())
                            Button { store.remove(item.id) } label: {
                                Text("删").font(.system(size: 12))
                            }
                            .buttonStyle(MiniButtonStyle())
                        }
                        .padding(.vertical, 6)
                    }
                    Button {
                        confirmClear = true
                    } label: {
                        Text("清空全部").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, 4)
                }
            }
        }
        .cardStyle()
    }

    private var noteCard: some View {
        Text("数据只存在本机，不联网，不上传。")
            .font(.system(size: 12))
            .foregroundColor(.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Text("扫码")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: 0x06121F))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accent)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: - helpers

    private func subtitle(_ item: Item) -> String {
        let prefix = item.code.isEmpty ? "" : "#\(item.code) · "
        return prefix + Fmt.short.string(from: item.exp)
    }

    private func pillForToday(_ item: Item) -> Pill {
        if item.exp < Date() {
            return Pill(text: "已过期 " + Fmt.short.string(from: item.exp), color: .bad)
        }
        let h = hoursLeft(item.exp)
        return Pill(text: "剩 \(h) 小时", color: h <= 2 ? .warn : .good)
    }

    private func pillForTomorrow(_ item: Item) -> Pill {
        Pill(text: "剩 \(hoursLeft(item.exp)) 小时", color: .warn)
    }

    private func pillForYesterday(_ item: Item) -> Pill {
        Pill(text: "已过期", color: .bad)
    }

    private func hoursLeft(_ date: Date) -> Int {
        max(1, Int((date.timeIntervalSinceNow / 3600).rounded()))
    }

    private func handleScan(_ text: String) {
        guard let parsed = PayloadParser.parse(text) else {
            show("识别到内容但不是效期码")
            return
        }
        let r = store.add(parsed)
        if r.isDuplicate {
            show("\(r.item.name) · 同一效期 +1，现在 ×\(r.item.qty)")
        } else {
            show("已记录：\(r.item.name)")
        }
    }

    private func addManual() {
        let text = manual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let parsed = PayloadParser.parse(text) else {
            show("请包含日期，例如 2026-11-11 23:59")
            return
        }
        let r = store.add(parsed)
        manual = ""
        show(r.isDuplicate ? "\(r.item.name) · ×\(r.item.qty)" : "已添加：\(r.item.name)")
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation {
                if toast == text { toast = nil }
            }
        }
    }
}

// MARK: - rows & chart

struct ItemRow: View {
    let item: Item
    let pill: Pill

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text((item.code.isEmpty ? "" : "#\(item.code) · ") + Fmt.short.string(from: item.exp))
                    .font(.system(size: 11))
                    .foregroundColor(.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if max(1, item.qty) > 1 {
                Text("×\(item.qty)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color(hex: 0x1B2B3F))
                    .cornerRadius(8)
            }
            Text(pill.text)
                .font(.system(size: 11))
                .foregroundColor(pill.color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().stroke(pill.color.opacity(0.5), lineWidth: 1))
        }
        .padding(.vertical, 8)
    }
}

struct WeekChart: View {
    let data: [(day: Date, count: Int)]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(1, data.map { $0.count }.max() ?? 1)
            let barArea = max(10, geo.size.height - 34)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { pair in
                    let index = pair.offset
                    let entry = pair.element
                    VStack(spacing: 6) {
                        Text(entry.count > 0 ? "\(entry.count)" : " ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(index == 0 ? Color(hex: 0xFF9A9A) : Color(hex: 0xCFE4FF))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor(index: index, count: entry.count))
                            .frame(height: max(4, barArea * CGFloat(entry.count) / CGFloat(maxValue)))
                        Text(index == 0 ? "今天" : Fmt.dayLabel.string(from: entry.day))
                            .font(.system(size: 10, weight: index == 0 ? .semibold : .regular))
                            .foregroundColor(index == 0 ? Color(hex: 0xFF9A9A) : Color.dim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
    }

    private func barColor(index: Int, count: Int) -> Color {
        if count == 0 { return Color(hex: 0x2B3140) }
        return index == 0 ? Color(hex: 0xFF6B6B) : Color(hex: 0x4DA3FF)
    }
}

// MARK: - styles

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 11)
            .background(Color(hex: 0x1E222B))
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct MiniButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(width: 30, height: 26)
            .background(Color(hex: 0x1E222B))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }
}
