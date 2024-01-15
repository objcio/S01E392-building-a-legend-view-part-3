//

import SwiftUI

struct HLine: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DiagonalPattern: View {
    var body: some View {

        GeometryReader { proxy in
            let line = HLine()
                .frame(width: proxy.size.width*2)
                .rotationEffect(.degrees(-45))

            let o = proxy.size.width/2
            ZStack {
                line
                    .offset(x: -o, y: -o)
                line
                line
                    .offset(x: o, y: o)
            }
        }
    }
}

extension Image {
    @MainActor static func striped(environment: EnvironmentValues, size: CGFloat, scale: CGFloat) -> Image {
        let content = DiagonalPattern()
            .frame(width: size, height: size)
            .environment(\.self, environment)
        let renderer =  ImageRenderer(content: content)
        renderer.scale = scale
        return Image(renderer.cgImage!, scale: scale, label: Text(""))
    }
}

struct DiagonalStripes: ShapeStyle {
    var size: CGFloat = 16

    @MainActor func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        .image(Image.striped(environment: environment, size: size, scale: environment.displayScale))
    }
}

struct LegendValue: PreferenceKey, Equatable, Identifiable {
    var bounds: Anchor<CGRect>
    var yInset: CGFloat = 0
    var label: String
    var index: Int

    var id: Int {
        index
    }

    static let defaultValue: [LegendValue] = []
    static func reduce(value: inout [LegendValue], nextValue: () -> [LegendValue]) {
        value.append(contentsOf: nextValue())
    }
}

struct Legend: ViewModifier {
    @State private var resolvedBounds: [(LegendValue, x: CGFloat)] = []
    @State private var highlightedItem: LegendValue.ID? = nil

    func computeItems(items: [LegendValue], proxy: GeometryProxy) -> [(LegendValue, x: CGFloat)] {
        guard !items.isEmpty else { return [] }
        let sorted = items.sorted { $0.index < $1.index }
        let resolved = sorted.map { proxy[$0.bounds] }
        var result: [CGFloat] = [resolved[0].midX]
        for idx in resolved.dropFirst().indices {
            var next = result[idx-1] + 20
            let bounds = resolved[idx]
            if next < bounds.minX || next > bounds.maxX {
                next = bounds.midX
            }
            result.append(next)
        }
        return Array(zip(sorted, result))
    }

    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
                .environment(\.highlightedLegendItem, highlightedItem)
                .overlayPreferenceValue(LegendValue.self) { value in
                    GeometryReader { proxy in
                        Color.clear.onChange(of: value, initial: true) {
                            resolvedBounds = computeItems(items: value, proxy: proxy)
                        }
                    }
                }
//                .overlay {
//                    if let (item, _) = resolvedBounds.first(where: { $0.0.id == highlightedItem }) {
//                        GeometryReader { proxy in
//                            let f = proxy[item.bounds]
//                            Rectangle()
//                                .stroke(lineWidth: 2)
//                                .foregroundStyle(.orange)
//                                .frame(width: f.width, height: f.height)
//                                .offset(x: f.minX, y: f.minY)
//                        }
//                    }
//                }
            VStack(alignment: .leading) {
                ForEach(resolvedBounds.reversed(), id: \.0.id) { (item, x) in
                    let primaryItem = highlightedItem == item.id || highlightedItem == nil
                    HStack {
                        Circle()
                            .frame(width: 3, height: 3)
                            .overlay {
                                GeometryReader { proxy in
                                    let f = proxy.frame(in: .local)
                                    let itemF = proxy[item.bounds]
                                    let height = f.midY - itemF.maxY + item.yInset
                                    Rectangle()
                                        .frame(width: 1)
                                        .frame(height: height)
                                        .offset(y: -height)
                                }
                                .frame(width: 1, height: 1)
                            }
                        Text(item.label)
                    }
                    .foregroundStyle(primaryItem ? .primary : .secondary)
                    .animation(.default, value: primaryItem)
                    .onHover(perform: { active in
                        highlightedItem = active ? item.id : nil
                    })
                    .offset(x: x)
                }
            }
        }
    }
}

extension View {
    func legend(_ label: String, index: Int, yInset: CGFloat = 0) -> some View {
        transformAnchorPreference(key: LegendValue.self, value: .bounds, transform: { previous, anchor in
            previous.append(LegendValue(bounds: anchor, yInset: yInset, label: label, index: index))
        })
    }

    func drawLegend() -> some View {
        modifier(Legend())
    }
}

struct HighlightedLegendItem: EnvironmentKey {
    static var defaultValue: LegendValue.ID? = nil
}

extension EnvironmentValues {
    var highlightedLegendItem: LegendValue.ID? {
        get { self[HighlightedLegendItem.self] }
        set { self[HighlightedLegendItem.self] = newValue }
    }
}

struct LegendItem<Content: View>: View {
    var title: String
    var index: Int
    var content: (Bool) -> Content
    @Environment(\.highlightedLegendItem) var highlightedID

    var body: some View {
        content(highlightedID == index)
            .legend(title, index: index)
    }
}

struct ContentView: View {
    var body: some View {
        let spacer =  Rectangle()
            .fill(DiagonalStripes())
            .frame(width: 16)
            .border(Color.primary)

        let highlightedSpacer =  Rectangle()
            .fill(DiagonalStripes())
            .frame(width: 16)
            .border(Color.orange, width: 3)
            .foregroundStyle(.orange)

        HStack(spacing: 0) {
            Color.blue
                .legend("Blue Rectangle", index: 0, yInset: 10)
            LegendItem(title: "Spacer 1", index: 1) { highlighted in
                spacer.overlay {
                    if highlighted {
                        highlightedSpacer
                    } else {
                        spacer
                    }
                }
            }
            Text("Hello, world")
            spacer
                .legend("Spacer 2", index: 3)
            Color.green
                .legend("Green Rectangle", index: 4, yInset: 10)
        }
        .frame(width: 250, height: 80)
        .legend("HStack", index: 2)
        .padding(40)
        .overlay {
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.black, lineWidth: 8)
        }
        .drawLegend()
        .padding()
    }
}

#Preview {
    ContentView()
        .frame(width: 400, height: 300)
}
