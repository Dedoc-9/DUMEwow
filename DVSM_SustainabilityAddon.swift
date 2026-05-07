// =====================================================
// DVSM v16.x — OPTIONAL SUSTAINABILITY ADD-ON MODULE
// ENERGY-AWARE EXECUTION + RESOURCE GOVERNANCE LAYER
// =====================================================
//
// PURPOSE:
// This module is an OPTIONAL extension to DVSM core.
//
// It introduces:
//   ✔ energy-aware runtime decisions
//   ✔ compute budget evaluation
//   ✔ degradation state signaling
//   ✔ governance throttling policy derivation
//   ✔ race-to-sleep optimization hooks
//
// DESIGN PRINCIPLE:
//   - zero modification of core DVSM files
//   - opt-in via protocol conformance
//   - no duplicate ownership of DVSMConfig or state enums
//
// =====================================================

import Foundation
import CryptoKit

// =====================================================
// MARK: - OPTIONAL ENERGY CONTROLLER CONTRACT
// =====================================================

public protocol DVSMEnergyAwareController {

    /// Evaluates current system load and returns next state
    func evaluateEnergyPressure(
        estimatedLoad: Double,
        config: DVSMConfig
    ) -> DVSMSystemState

    /// Optional governance throttle policy generator
    func makeThrottlePolicy(
        from config: DVSMConfig
    ) -> DVSMGovernanceThrottlePolicy
}

// =====================================================
// MARK: - CORE IMPLEMENTATION (DEFAULT LOGIC)
// =====================================================

public extension DVSMEnergyAwareController {

    func evaluateEnergyPressure(
        estimatedLoad: Double,
        config: DVSMConfig
    ) -> DVSMSystemState {

        let budget = config.derivedResourceBudget()

        // =====================================================
        // CORE RULE:
        // If load exceeds safe energy envelope → degrade safely
        // =====================================================

        if estimatedLoad > budget.computeBudget * 1.5 {
            return .degraded
        }

        if estimatedLoad > budget.computeBudget {
            return .ready
        }

        return .ready
    }

    func makeThrottlePolicy(
        from config: DVSMConfig
    ) -> DVSMGovernanceThrottlePolicy {

        let budget = config.derivedResourceBudget()

        return DVSMGovernanceThrottlePolicy.from(budget)
    }
}

// =====================================================
// MARK: - RACE-TO-SLEEP OPTIMIZATION LAYER
// =====================================================

public struct DVSMRaceToSleepScheduler {

    /// Determines whether system should batch operations
    public static func shouldBatchOperations(
        load: Double,
        config: DVSMConfig
    ) -> Bool {

        let budget = config.derivedResourceBudget()

        // low load → sleep more aggressively
        return load < (budget.computeBudget * 0.4)
    }

    /// Determines safe execution delay window
    public static func recommendedDelay(
        load: Double,
        config: DVSMConfig
    ) -> TimeInterval {

        let budget = config.derivedResourceBudget()

        switch load {

        case ..<0.2:
            return 2.5   // aggressive batching

        case ..<0.5:
            return 1.0   // moderate batching

        case ..<1.0:
            return 0.2   // near real-time

        default:
            return 0.0   // immediate execution
        }
    }
}

// =====================================================
// MARK: - SUSTAINABILITY RESOURCE ENVELOPE (OPTIONAL EXTENSION MODEL)
// =====================================================

public struct DVSMResourceEnvelope: Sendable {

    public let mode: DVSMSustainabilityMode
    public let computeBudget: Double
    public let energyCeiling: Double
    public let batchWindow: TimeInterval

    public init(
        mode: DVSMSustainabilityMode,
        computeBudget: Double,
        energyCeiling: Double,
        batchWindow: TimeInterval
    ) {
        self.mode = mode
        self.computeBudget = computeBudget
        self.energyCeiling = energyCeiling
        self.batchWindow = batchWindow
    }

    /// Factory mapping from config mode → envelope
    public static func from(_ config: DVSMConfig) -> DVSMResourceEnvelope {

        let budget = config.derivedResourceBudget()

        let delay = DVSMRaceToSleepScheduler.recommendedDelay(
            load: budget.computeBudget,
            config: config
        )

        return DVSMResourceEnvelope(
            mode: config.sustainabilityMode,
            computeBudget: budget.computeBudget,
            energyCeiling: budget.energySensitivity,
            batchWindow: delay
        )
    }
}

// =====================================================
// MARK: - GOVERNANCE INTEGRATION HOOK (NON-INTRUSIVE)
// =====================================================

public extension DVSMSystemLifecycleManaging {

    /// Optional helper: apply sustainability-aware state transition
    func applySustainabilityTransition(
        currentState: DVSMSystemState,
        estimatedLoad: Double,
        config: DVSMConfig
    ) -> DVSMSystemState {

        let budget = config.derivedResourceBudget()

        if estimatedLoad > budget.computeBudget * 1.5 {
            return .degraded
        }

        if budget.maxGovernanceDepth <= 1 {
            return .sealed
        }

        return currentState
    }
}

// =====================================================
// MARK: - IP / COPYLEFT / INTEGRATION NOTES (WHITEPAPER HOOK)
// =====================================================
//
// LICENSING MODEL (INTENT FRAMEWORK):
//
// This module is designed for:
//
//   ✔ Copyleft-compatible systems
//   ✔ Dual-license commercial integration
//   ✔ Research-only forks (non-production)
//   ✔ Embedded systems with attribution tracking
//
// INTEGRATION RULE:
//
// If DVSM core is modified:
//
//   → must preserve provenance layer
//   → must preserve deterministic state transitions
//   → must preserve audit fingerprinting
//
// OPTIONAL EXTENSION RULE:
//
// This file MAY be:
//   - removed without affecting core DVSM
//   - replaced with vendor-specific optimization layer
//   - extended for hardware-specific tuning
//
// =====================================================
// END OPTIONAL SUSTAINABILITY ADD-ON
// =====================================================
