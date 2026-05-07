// =========================================================================
// DVSM v16.2-X — KERNEL CORE: IDENTIFIABILITY-GATED SUBSTRATE
// =========================================================================

use crate::regime_governor::{RegimeGovernor, IdentifiabilityStatus};
use crate::noise_geometry::{NoiseGeometry, ShardId};
use crate::execution_governor::ExecutionGovernor;

pub struct DVSMKernel {
    /// The geometric uncertainty model (Hierarchical Tensors)
    noise_model: NoiseGeometry,
    /// Identifiability monitor (Bayesian + Spectral)
    regime_monitor: RegimeGovernor,
    /// Execution plane (Binary Trace + Physical Probes)
    execution_plane: ExecutionGovernor,
}

impl DVSMKernel {
    /// THE ATOMIC PULSE
    /// Validates that state transitions remain identifiable within the current 
    /// noise geometry before committing irreversibility.
    pub fn pulse(&mut self, action: Action, shard: ShardId) -> Result<SSP, EpistemicError> {
        
        // 1. COMPUTE SENSITIVITY-WEIGHTED DETECTABILITY (MDD)
        // Adjoint gain determines how much input noise is amplified by the model.
        let sensitivity = self.regime_monitor.get_adjoint_gain();
        let mdd_threshold = self.noise_model.compute_mdd(shard, sensitivity);

        // 2. AUDIT IDENTIFIABILITY
        // Check if the current observation separates H0 from H1 given the MDD.
        let status = self.regime_monitor.audit_identifiability(mdd_threshold)?;
        
        if !status.is_unique() {
            let rcc = status.generate_collapse_certificate();
            return Err(EpistemicError::IdentifiabilityLoss(rcc));
        }

        // 3. CROSS-SHARD CONSISTENCY CHECK
        // Ensure local noise geometry hasn't drifted from the global prior.
        self.noise_model.verify_consistency(shard)?;

        // 4. EXECUTION & CLOSURE
        let report = self.execution_plane.execute_with_probes(action)?;
        self.finalize_ssp(report)
    }
}

pub enum EpistemicError {
    IdentifiabilityLoss(CollapseCertificate),
    NoiseConsistencyFailure, // Wasserstein distance exceeded global hyperprior
    ObserverDrift,
    ExecutionFailure(String),
}
