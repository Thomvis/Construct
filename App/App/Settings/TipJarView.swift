import SwiftUI
import StoreKit

struct TipSize {
    let storeKitId: String
    let iconScale: CGFloat

    static func tip(_ sizeString: String, iconScale: CGFloat) -> Self {
        Self(storeKitId: "me.thomasvisser.construct5e.tip.\(sizeString)", iconScale: iconScale)
    }

    static let small = Self.tip("small", iconScale: 0.75)
    static let medium = Self.tip("medium", iconScale: 1.0)
    static let large = Self.tip("large", iconScale: 1.5)

    static let all = [small, medium, large]
}

struct TipJarView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @State private var latestTipDate: Date?
    @State private var transactionTaskId = UUID()

    var body: some View {
        ScrollView {
            if let latestTipDate {
                TopNoticeView(
                    title: "🙏 Thank you!",
                    description: """
                        You last tipped \(latestTipDate.formatted(.relative(presentation: .numeric))).
                        Construct is brimming with magical energy.
                        """
                )
                .id(latestTipDate)
                .transition(.scale)
            } else {
                TopNoticeView(
                    title: "Toss a coin to your Construct...",
                    description: "Appropriately sized tips power the magic that binds Construct to your will."
                )
            }

            StoreView(ids: TipSize.all.map(\.storeKitId)) { product in
                if let tipSize = TipSize.all.first(where: { $0.storeKitId == product.id }) {
                    Image("tabbar_d20")
                        .scaleEffect(tipSize.iconScale)
                        .foregroundStyle(.white)
                        .padding()
                        .background {
                            Circle()
                                .foregroundStyle(Color.purple.gradient)
                        }
                }
            }
            .productViewStyle(.regular)
            .storeButton(.hidden, for: .cancellation)
            .onInAppPurchaseCompletion { product, result in
                if case .success = result.value {
                    self.transactionTaskId = UUID()
                }
            }
        }
        .task(id: transactionTaskId) {
            let start = Date()
            // Check latest tip
            async let small = Transaction.latest(for: "me.thomasvisser.construct5e.tip.small")
            async let medium = Transaction.latest(for: "me.thomasvisser.construct5e.tip.medium")
            async let large = Transaction.latest(for: "me.thomasvisser.construct5e.tip.large")

            let d = await [small, medium, large].reduce(Optional<Date>.none) { partialResult, result in
                if let result, let payload = try? result.payloadValue {
                    if let partialResult {
                        return max(partialResult, payload.purchaseDate)
                    } else {
                        return payload.purchaseDate
                    }
                } else {
                    return partialResult
                }
            }

            // Ensure we've waited at least a second
            let elapsed = Date().timeIntervalSince(start)
            try? await Task.sleep(for: .seconds(max(0, 1 - elapsed)))
            withAnimation(.bouncy(extraBounce: 0.1)) {
                self.latestTipDate = d
            }
        }
        .navigationTitle("Tip Jar")
    }

    struct TopNoticeView: View {
        let title: String
        let description: String

        var body: some View {
            VStack(spacing: 12) {
                Text(title).bold()
                Text(description)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground).cornerRadius(4))
            .padding()
        }
    }
}

#if DEBUG
struct TipView_Previews: PreviewProvider {
    static var previews: some View {
        SheetNavigationContainer {
            TipJarView()
        }
    }
}
#endif
