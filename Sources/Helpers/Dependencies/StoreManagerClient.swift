//
//  StoreManagerClient.swift
//  
//
//  Created during migration to swift-dependencies
//

import Foundation
import StoreKit
import ComposableArchitecture

public struct StoreManagerClient {
    public var beginObservingTransactionUpdates: () -> Void
    public var checkForUnfinishedTransactions: () async -> Void
    
    public init(
        beginObservingTransactionUpdates: @escaping () -> Void,
        checkForUnfinishedTransactions: @escaping () async -> Void
    ) {
        self.beginObservingTransactionUpdates = beginObservingTransactionUpdates
        self.checkForUnfinishedTransactions = checkForUnfinishedTransactions
    }
}

extension StoreManagerClient: DependencyKey {
    public static var liveValue: StoreManagerClient {
        let manager = StoreManager()
        
        return StoreManagerClient(
            beginObservingTransactionUpdates: {
                manager.beginObservingTransactionUpdates()
            },
            checkForUnfinishedTransactions: {
                await manager.checkForUnfinishedTransactions()
            }
        )
    }
}

public extension DependencyValues {
    var storeManager: StoreManagerClient {
        get { self[StoreManagerClient.self] }
        set { self[StoreManagerClient.self] = newValue }
    }
}

// Internal StoreManager class - moved from App/App/App/StoreManager.swift
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

