import StoreKit

class StoreManager {

    func beginObservingTransactionUpdates() {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { break }
                await self.process(transaction: update)
            }
        }
    }

    func checkForUnfinishedTransactions() async {
        for await transaction in Transaction.unfinished {
            await self.process(transaction: transaction)
        }
    }

    private func process(transaction: VerificationResult<Transaction>) async {
        do {
            if try transaction.payloadValue.productType == .consumable {
                try await transaction.payloadValue.finish()
            }
        } catch {
            print("Failed to process transaction: \(transaction)")
        }
    }
}
