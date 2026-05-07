// =====================================================
// DVSM v16 RESEARCH KERNEL
// MERKLE DAG + REGIME GOVERNANCE + EPISTEMIC ARBITRATION LAYER
// =====================================================

import Foundation
import CryptoKit

// =====================================================
// MARK: - TRUST ZONES (EPISTEMIC REGIMES)
// =====================================================

public enum TrustZone: String, Codable, Sendable {
    case ingest        // data entry
    case compute       // transformation
    case audit         // verification layer
    case external      // arbitration / human boundary
}

// =====================================================
// MARK: - NODE CONTEXT (SHARDED OBSERVER MODEL)
// =====================================================

public struct NodeContext: Sendable {
    public let nodeID: String
    public let shardKey: String
    public let substrateSignature: Data   // ← BIH-like physical identity hook
}

// =====================================================
// MARK: - PROBABILISTIC GOVERNANCE LAYER
// =====================================================

public enum ProbabilisticDecision: Sendable, CustomStringConvertible {
    case accept
    case degrade(Float)   // uncertainty increase
    case mutate(Float)    // regime shift allowed
    case reject(String)   // epistemic failure

    public var description: String {
        switch self {
        case .accept: return "ACCEPT"
        case .degrade(let f): return "DEGRADE(\(f))"
        case .mutate(let f): return "MUTATE(\(f))"
        case .reject(let r): return "REJECT(\(r))"
        }
    }
}

// =====================================================
// MARK: - CRYPTO LAYER
// =====================================================

public struct SHA256Hasher {
    public static func hash(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

// =====================================================
// MARK: - MERKLE DAG NODE (EPISTEMICALLY ANCHORED)
// =====================================================

public struct MerkleDAGNode: Sendable {
    public let id: String
    public let hash: Data
    public let parents: [Data]
    public let shard: String
    public let timestamp: UInt64

    // epistemic extension (DVSM integration point)
    public let uncertaintyWeight: Float
}

// =====================================================
// MARK: - AUDIT RECORD (GOVERNED TRACE LAYER)
// =====================================================

public struct AuditRecordV3: Sendable {
    public let id: String
    public let hash: Data
    public let prevHash: Data?
    public let shard: String
    public let zone: TrustZone
    public let timestamp: UInt64

    public let decisionWeight: Float
}

// =====================================================
// MARK: - MERKLE DAG ACCUMULATOR
// =====================================================

public struct IncrementalMerkleDAG {

    private(set) var roots: [String: Data] = [:]

    public mutating func update(shard: String, leaf: Data) {
        let prev = roots[shard] ?? Data()
        roots[shard] = SHA256Hasher.hash(prev + leaf)
    }

    public func root(for shard: String) -> Data {
        roots[shard] ?? Data()
    }

    public func globalRoot() -> Data {
        let sorted = roots.keys.sorted()
        let combined = sorted.compactMap { roots[$0] }.reduce(Data(), +)
        return SHA256Hasher.hash(combined)
    }
}

// =====================================================
// MARK: - DVSM v16 RESEARCH ENGINE (HYBRID CORE)
// =====================================================

public final class DVSMv16Engine {

    // -------------------------
    // CORE STATE
    // -------------------------

    private var dag = IncrementalMerkleDAG()
    private var shardChains: [String: [AuditRecordV3]] = [:]
    private var pendingNodes: [String: [MerkleDAGNode]] = [:]
    private var counter: UInt64 = 0

    // =====================================================
    // MARK: - INGESTION LAYER (NEURAL-ADJACENT VECTOR ENTRY)
    // =====================================================

    public func ingest(
        id: String,
        vector: [Float],
        node: NodeContext,
        decision: ProbabilisticDecision
    ) {

        counter += 1
        let timestamp = counter

        // vector → deterministic entropy embedding
        let vectorData = Data(vector.map { $0.bitPattern }.flatMap {
            withUnsafeBytes(of: $0.bigEndian, Array.init)
        })

        let parentRoot = dag.root(for: node.shardKey)

        let leafHash = SHA256Hasher.hash(
            parentRoot +
            vectorData +
            node.substrateSignature +
            Data(id.utf8)
        )

        let dagNode = MerkleDAGNode(
            id: id,
            hash: leafHash,
            parents: [parentRoot],
            shard: node.shardKey,
            timestamp: timestamp,
            uncertaintyWeight: Self.decisionWeight(decision)
        )

        pendingNodes[node.shardKey, default: []].append(dagNode)
        dag.update(shard: node.shardKey, leaf: leafHash)

        let record = AuditRecordV3(
            id: id,
            hash: leafHash,
            prevHash: parentRoot,
            shard: node.shardKey,
            zone: .ingest,
            timestamp: timestamp,
            decisionWeight: Self.decisionWeight(decision)
        )

        shardChains[node.shardKey, default: []].append(record)
    }

    // =====================================================
    // MARK: - GOVERNANCE TRANSLATION FUNCTION
    // =====================================================

    private static func decisionWeight(_ d: ProbabilisticDecision) -> Float {
        switch d {
        case .accept: return 1.0
        case .degrade(let f): return 1.0 - f
        case .mutate(let f): return 0.5 + f
        case .reject: return 0.0
        }
    }

    // =====================================================
    // MARK: - ARBITRATION INTERFACE (DVSM INTEGRATION POINT)
    // =====================================================

    public func arbitrationSnapshot(shard: String) -> Data {
        let chain = shardChains[shard] ?? []
        let hashes = chain.map { $0.hash }.reduce(Data(), +)
        return SHA256Hasher.hash(hashes + dag.root(for: shard))
    }

    // =====================================================
    // MARK: - MERKLE PROOF (SIMPLIFIED)
    // =====================================================

    public struct MerkleProof {
        public let leaf: Data
        public let root: Data
        public let siblings: [Data]
    }
}
