// =====================================================
// RILC — RUNTIME INTEGRITY & LATENCY CONTRACT LAYER
// Pluggable Governance Shell for DVME / DVSM systems
// =====================================================

import Foundation
import CryptoKit

// =====================================================
// MARK: - EXECUTION MODE CONTRACT
// =====================================================

public enum ExecutionContractMode: Sendable {
    case realtime      // gaming / low-latency path
    case deterministic // strict replay-safe execution
    case forensic      // full audit + verification mode
    case degraded      // safety fallback (entropy or drift detected)
}

// =====================================================
// MARK: - SYSTEM ENVELOPE (IMMUTABLE STATE UNIT)
// =====================================================

public struct ExecutionEnvelope: Sendable {
    public let sequence: UInt64
    public let payloadHash: Data
    public let prevHash: Data
    public let timestamp: UInt64
}

// =====================================================
// MARK: - RILC CONFIGURATION
// =====================================================

public struct RILCConfig: Sendable {

    // Gaming latency constraint (soft real-time target)
    public let maxFrameLatencyMs: Double

    // Hard safety bound (must never exceed)
    public let hardLatencyCeilingMs: Double

    // Maximum allowed entropy drift per operation
    public let entropyBudget: Float

    // Replay determinism strictness
    public let requireStrictDeterminism: Bool
}

// =====================================================
// MARK: - GOVERNANCE + VERIFICATION CORE
// =====================================================

public final class RILCRuntimeIntegrityLayer {

    private let config: RILCConfig
    private var lastEnvelopeHash: Data = Data()
    private var frameLatencyMs: Double = 0
    private var entropyLevel: Float = 0

    public init(config: RILCConfig) {
        self.config = config
    }

    // =====================================================
    // MARK: - PRE-EXECUTION GATE (LATENCY + SAFETY CONTRACT)
    // =====================================================

    public func preflight(
        estimatedLatencyMs: Double,
        estimatedEntropy: Float
    ) -> ExecutionContractMode {

        // -----------------------------------------
        // 1. HARD LATENCY SAFETY BOUND
        // -----------------------------------------

        if estimatedLatencyMs > config.hardLatencyCeilingMs {
            return .degraded
        }

        // -----------------------------------------
        // 2. GAMING / REAL-TIME TARGET
        // -----------------------------------------

        if estimatedLatencyMs <= config.maxFrameLatencyMs &&
           estimatedEntropy <= config.entropyBudget {
            return .realtime
        }

        // -----------------------------------------
        // 3. DETERMINISTIC SAFE MODE
        // -----------------------------------------

        if config.requireStrictDeterminism {
            return .deterministic
        }

        return .forensic
    }

    // =====================================================
    // MARK: - ENVELOPE VALIDATION (REPLAY INTEGRITY)
    // =====================================================

    public func validate(envelope: ExecutionEnvelope) -> Bool {

        // Ensure monotonic chain integrity
        if envelope.prevHash != lastEnvelopeHash && !lastEnvelopeHash.isEmpty {
            return false
        }

        // Update state
        lastEnvelopeHash = envelope.payloadHash
        return true
    }

    // =====================================================
    // MARK: - RUNTIME FEEDBACK LOOP
    // =====================================================

    public func commit(
        actualLatencyMs: Double,
        actualEntropy: Float,
        envelope: ExecutionEnvelope
    ) {

        self.frameLatencyMs = actualLatencyMs
        self.entropyLevel = actualEntropy

        _ = validate(envelope: envelope)
    }

    // =====================================================
    // MARK: - DETECTION FLAGS (STATE-LEVEL SECURITY SIGNALS)
    // =====================================================

    public func isUnderLatencyStress() -> Bool {
        frameLatencyMs > config.maxFrameLatencyMs
    }

    public func isEntropyUnsafe() -> Bool {
        entropyLevel > config.entropyBudget
    }

    public func requiresForensicMode() -> Bool {
        isUnderLatencyStress() || isEntropyUnsafe()
    }
}
