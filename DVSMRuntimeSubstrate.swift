// =====================================================
// DVSM v16.2-R — UNIFIED RUNTIME SUBSTRATE
// EXECUTION + UNCERTAINTY GEOMETRY LAYER
// =====================================================

import Foundation
import CryptoKit
import simd

// =====================================================
// MARK: - SHARED TYPES
// =====================================================

public typealias ShardId = UInt32

// =====================================================
// MARK: - STRUCTURED ENTROPY STATE (FIX: unified meaning)
// =====================================================

public struct EntropyState: Sendable {
    public let vector: SIMD4<Float>
}

// =====================================================
// MARK: - EXECUTION ENVELOPE (IMMUTABLE TRACE UNIT)
// =====================================================

public struct ExecutionEnvelope: Sendable {
    public let sequence: UInt64
    public let payloadHash: Data
    public let prevHash: Data
    public let timestamp: UInt64
    public let shard: ShardId
}

// =====================================================
// MARK: - RUNTIME SIGNAL SPACE
// =====================================================

public struct RuntimeSignals: Sendable {
    public let latencyMs: Double
    public let entropy: EntropyState
}

// =====================================================
// MARK: - EXECUTION MODES
// =====================================================

public enum ExecutionMode: Sendable {
    case realtime
    case deterministic
    case forensic
    case degraded(reason: String)
}

// =====================================================
// MARK: - GLOBAL NOISE MODEL (UNIFIED WITH RILC)
// =====================================================

public struct CovarianceModel: Sendable {
    public var matrix: simd_double4x4
    public var drift: SIMD4<Double>
}

// =====================================================
// MARK: - NOISE GEOMETRY + EXECUTION STATE
// =====================================================

public final class DVSMRuntimeSubstrate {

    // =====================================================
    // GLOBAL STATE (FIXED vs LOCAL SEPARATION)
    // =====================================================

    private let globalPrior: CovarianceModel
    private var localModels: [ShardId: CovarianceModel]

    private let maxLatency: Double
    private let hardLatency: Double
    private let entropyBudget: SIMD4<Float>

    // =====================================================
    // INIT
    // =====================================================

    public init(
        globalPrior: CovarianceModel,
        maxLatency: Double,
        hardLatency: Double,
        entropyBudget: SIMD4<Float>
    ) {
        self.globalPrior = globalPrior
        self.localModels = [:]
        self.maxLatency = maxLatency
        self.hardLatency = hardLatency
        self.entropyBudget = entropyBudget
    }

    // =====================================================
    // MARK: - SHARD REGISTRATION
    // =====================================================

    public func registerShard(_ shard: ShardId, model: CovarianceModel) {
        localModels[shard] = model
    }

    // =====================================================
    // MARK: - MDD (UNIFIED UNCERTAINTY FUNCTION)
    // FIX: replaces determinant instability
    // =====================================================

    public func mdd(for shard: ShardId) -> Double {

        guard let local = localModels[shard] else { return 1.0 }

        // FIX: stable uncertainty proxy (trace-based instead of det)
        let traceLocal =
            local.matrix[0,0] +
            local.matrix[1,1] +
            local.matrix[2,2] +
            local.matrix[3,3]

        return abs(traceLocal)
    }

    // =====================================================
    // MARK: - CROSS-SHARD DRIFT (STABLE METRIC)
    // =====================================================

    public func drift(for shard: ShardId) -> Double {

        guard let local = localModels[shard] else { return 0.0 }

        let diff = local.matrix - globalPrior.matrix

        // Frobenius norm approximation
        var sum: Double = 0
        for i in 0..<4 {
            for j in 0..<4 {
                sum += diff[i,j] * diff[i,j]
            }
        }

        return sqrt(sum)
    }

    // =====================================================
    // MARK: - ENTROPY VALIDATION (CONTROL PLANE)
    // =====================================================

    public func entropyUnsafe(_ entropy: EntropyState) -> Bool {
        zip(entropy.vector, entropyBudget).contains { $0 > $1 }
    }

    // =====================================================
    // MARK: - EXECUTION MODE DECISION (UNIFIED GOVERNANCE)
    // =====================================================

    public func decide(
        shard: ShardId,
        signals: RuntimeSignals
    ) -> ExecutionMode {

        if signals.latencyMs > hardLatency {
            return .degraded(reason: "hard latency ceiling")
        }

        if entropyUnsafe(signals.entropy) {
            return .forensic
        }

        let uncertainty = mdd(for: shard)
        let driftValue = drift(for: shard)

        // FIX: unified scalar projection of geometry
        let instability = uncertainty + driftValue

        if signals.latencyMs <= maxLatency && instability < 10.0 {
            return .realtime
        }

        return .deterministic
    }

    // =====================================================
    // MARK: - ENVELOPE VALIDATION (PURE STATE CONSISTENCY)
    // =====================================================

    public func validate(
        envelope: ExecutionEnvelope,
        expectedPrevHash: Data
    ) -> Bool {
        envelope.prevHash == expectedPrevHash
    }

    // =====================================================
    // MARK: - COMMIT (REPLAY-ABLE STATE UPDATE)
    // =====================================================

    public func commit(
        shard: ShardId,
        envelope: ExecutionEnvelope,
        signals: RuntimeSignals
    ) -> Data {

        let entropyBytes = Data(signals.entropy.vector.withUnsafeBytes { Data($0) })

        let combined =
            envelope.payloadHash +
            entropyBytes +
            Data(withUnsafeBytes(of: shard.bigEndian, Array.init))

        return Data(SHA256.hash(data: combined))
    }
}
