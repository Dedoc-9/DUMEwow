// =========================================================================
// DVSM v16.2-X — KERNEL CORE: IDENTIFIABILITY-GATED SUBSTRATE
// =========================================================================

use crate::regime_governor::{RegimeGovernor, IdentifiabilityStatus, MigrationContext};
use crate::noise_geometry::{NoiseGeometry, ShardId};
use crate::execution_governor::ExecutionGovernor;

pub struct DVSMKernel {
    /// Hierarchical uncertainty model (immutable global prior + shard tensors)
    noise_model: NoiseGeometry,

    /// Identifiability monitor (Bayesian + Spectral + migration-aware weighting)
    regime_monitor: RegimeGovernor,

    /// Physical execution + probes
    execution_plane: ExecutionGovernor,
}

impl DVSMKernel {
    /// THE ATOMIC PULSE
    pub fn pulse(&mut self, action: Action, shard: ShardId) -> Result<SSP, EpistemicError> {

        // 0. MIGRATION-AWARE CREDIBILITY CONTEXT
        // Determines whether shard is fully trusted or in transition phase.
        let migration_ctx: MigrationContext =
            self.regime_monitor.get_migration_context(shard)?;

        // 1. IDENTIFIABILITY CHECK (WEIGHTED BY MIGRATION STATE)
        let sensitivity = self.regime_monitor.get_adjoint_gain();

        let mdd_threshold = self
            .noise_model
            .compute_mdd(shard, sensitivity, &migration_ctx);

        let status = self
            .regime_monitor
            .audit_identifiability(mdd_threshold, &migration_ctx)?;

        if !status.is_unique() {
            let rcc = status.generate_collapse_certificate();
            return Err(EpistemicError::IdentifiabilityLoss(rcc));
        }

        // 2. CROSS-SHARD CONSISTENCY (GLOBAL PRIOR IS IMMUTABLE)
        self.noise_model.verify_consistency(shard)?;

        // 3. EXECUTION ONLY IF SHARD IS VALID PARTICIPANT
        if !migration_ctx.is_active() {
            return Err(EpistemicError::UntrustedRegimeMode);
        }

        let report = self.execution_plane.execute_with_probes(action)?;
        self.finalize_ssp(report)
    }
}

pub enum EpistemicError {
    IdentifiabilityLoss(CollapseCertificate),
    NoiseConsistencyFailure,
    ObserverDrift,
    ExecutionFailure(String),
    UntrustedRegimeMode,
}
}
