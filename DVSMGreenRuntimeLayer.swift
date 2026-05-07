// =====================================================
// DVSM v16.x — GREEN RUNTIME ADAPTATION LAYER
// ENERGY-AWARE + ADAPTIVE VERIFICATION SUBSYSTEM
// =====================================================
//
// PURPOSE:
// Reduces computational overhead of DVSM systems by
// dynamically scaling verification, cryptography, and
// governance intensity based on risk + system stability.
//
// DESIGN GOALS:
//
//   🌱 minimize constant cryptographic cost
//   🌱 reduce DAG + hashing frequency
//   🌱 avoid full identifiability checks unless needed
//   🌱 maintain safety under probabilistic trust scaling
//
// =====================================================

import Foundation
import CryptoKit

// =====================================================
// MARK: - ENERGY / COST PROFILE
// =====================================================

public enum DVSMComputeMode: Sendable {
    case ultraLight     // minimal checks (edge / IoT scale)
    case balanced       // default production mode
    case hardened       // increased verification
    case forensic       // full DVSM verification stack
}

// =====================================================
// MARK: - SYSTEM LOAD SIGNALS
// =====================================================

public struct DVSMSystemLoad: Sendable {

    public let cpuPressure: Double
    public let memoryPressure: Double
    public let shardVolatility: Double
    public let anomalyScore: Double

    public init(cpuPressure: Double,
                memoryPressure: Double,
                shardVolatility: Double,
                anomalyScore: Double) {
        self.cpuPressure = cpuPressure
        self.memoryPressure = memoryPressure
        self.shardVolatility = shardVolatility
        self.anomalyScore = anomalyScore
    }

    public var isStable: Bool {
        cpuPressure < 0.6 &&
        memoryPressure < 0.6 &&
        shardVolatility < 0.4 &&
        anomalyScore < 0.3
    }
}

// =====================================================
// MARK: - ADAPTIVE GOVERNANCE ENGINE
// =====================================================

public struct DVSMGreenGovernor {

    public init() {}

    /// Determines runtime execution cost mode dynamically
    public func computeMode(load: DVSMSystemLoad) -> DVSMComputeMode {

        // ----------------------------
        // LOW COST MODE (green path)
        // ----------------------------
        if load.isStable {
            return .ultraLight
        }

        // ----------------------------
        // MODERATE RISK
        // ----------------------------
        if load.anomalyScore < 0.6 {
            return .balanced
        }

        // ----------------------------
        // HIGH RISK ENVIRONMENT
        // ----------------------------
        if load.anomalyScore < 0.85 {
            return .hardened
        }

        // ----------------------------
        // CRITICAL / FORENSIC MODE
        // ----------------------------
        return .forensic
    }
}

// =====================================================
// MARK: - ADAPTIVE VERIFICATION STRATEGY
// =====================================================

public struct DVSMGreenVerification {

    public static func shouldRunFullDAGSync(
        mode: DVSMComputeMode
    ) -> Bool {
        switch mode {
        case .ultraLight:
            return false
        case .balanced:
            return false
        case .hardened:
            return true
        case .forensic:
            return true
        }
    }

    public static func shouldRunIdentifiabilityCheck(
        mode: DVSMComputeMode
    ) -> Bool {
        switch mode {
        case .ultraLight:
            return false
        case .balanced:
            return true
        case .hardened:
            return true
        case .forensic:
            return true
        }
    }

    public static func shouldRunBIHProbe(
        mode: DVSMComputeMode
    ) -> Bool {
        mode == .forensic || mode == .hardened
    }
}

// =====================================================
// MARK: - LIGHTWEIGHT HASH STRATEGY
// =====================================================

public struct DVSMGreenHasher {

    /// Lightweight hash (replaces full DAG recompute in low-cost mode)
    public static func fastHash(_ data: Data) -> Data {
        let truncated = SHA256.hash(data: data).prefix(16)
        return Data(truncated)
    }

    /// Full-strength hash (for forensic mode only)
    public static func fullHash(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

// =====================================================
// MARK: - ENERGY-AWARE EXECUTION WRAPPER
// =====================================================

public struct DVSMGreenExecutionContext {

    public let mode: DVSMComputeMode

    public init(mode: DVSMComputeMode) {
        self.mode = mode
    }

    public func execute(data: Data) -> Data {

        // -----------------------------------------
        // ULTRA LIGHT PATH (EDGE OPTIMIZED)
        // -----------------------------------------
        if mode == .ultraLight {
            return DVSMGreenHasher.fastHash(data)
        }

        // -----------------------------------------
        // NORMAL PATH
        // -----------------------------------------
        if mode == .balanced {
            return DVSMGreenHasher.fastHash(data)
        }

        // -----------------------------------------
        // HARDENED / FORENSIC PATH
        // -----------------------------------------
        return DVSMGreenHasher.fullHash(data)
    }
}

// =====================================================
// MARK: - SYSTEM SUMMARY
// =====================================================
//
// This layer introduces:
//
//   🌱 adaptive verification scaling
//   🌱 reduced cryptographic overhead
//   🌱 load-based governance switching
//   🌱 energy-aware execution tiers
//
// RESULT:
//
// DVSM no longer runs at constant maximum cost.
//
// Instead:
//
//   → It behaves like a *variable-resolution trust system*
//
// where computation cost is proportional to risk.
//
// =====================================================
