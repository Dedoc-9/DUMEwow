// =========================================================================
// DVSM v16.2-X — REGIME GOVERNOR: BAYESIAN IDENTIFIABILITY MONITOR
// =========================================================================

use crate::noise_geometry::{NoiseGeometry, ShardId};
use crate::kernel_core::EpistemicError;

pub struct RegimeGovernor {
    /// Hierarchical uncertainty substrate (shared truth about noise)
    noise_geometry: NoiseGeometry,

    /// Migration state per shard (regime lifecycle)
    migration_registry: std::collections::HashMap<ShardId, MigrationContext>,

    /// Adjoint sensitivity gain (affects identifiability window)
    adjoint_state: f64,
}

#[derive(Clone)]
pub struct MigrationContext {
    pub phase: MigrationPhase,
    pub samples_collected: u64,
    pub convergence_score: f64,
}

#[derive(Clone)]
pub enum MigrationPhase {
    Settling,
    Stabilizing,
    Active,
}

impl MigrationContext {
    pub fn credibility_weight(&self) -> f64 {
        match self.phase {
            MigrationPhase::Settling => 5.0,
            MigrationPhase::Stabilizing => 1.0 + (4.0 * (1.0 - self.convergence_score)),
            MigrationPhase::Active => 1.0,
        }
    }

    pub fn is_active(&self) -> bool {
        matches!(self.phase, MigrationPhase::Active)
    }
}

pub enum IdentifiabilityStatus {
    Unique,
    Collapsed {
        overlap_score: f64,
        mdd_used: f64,
        shard_drift: f64,
    },
}

impl RegimeGovernor {

    /// Computes identifiability of H0 vs H1 under *physical noise geometry*
    pub fn audit_identifiability(
        &self,
        shard: ShardId,
        mdd: f64,
    ) -> Result<IdentifiabilityStatus, EpistemicError> {

        let ctx = self.get_migration_context(shard)?;

        // 1. Local geometric uncertainty (physical substrate)
        let local_mdd = self.noise_geometry.compute_mdd(shard, self.adjoint_state);

        // 2. Migration-aware weighting (regime instability correction)
        let effective_mdd = local_mdd * ctx.credibility_weight();

        // 3. Posterior overlap (model indistinguishability proxy)
        let overlap = self.compute_posterior_overlap(shard)?;

        // 4. Cross-shard drift (detect early CEC formation)
        let drift = self.noise_geometry.cross_shard_drift(shard)?;

        // 5. Identifiability test
        if overlap > effective_mdd {
            return Ok(IdentifiabilityStatus::Collapsed {
                overlap_score: overlap,
                mdd_used: effective_mdd,
                shard_drift: drift,
            });
        }

        Ok(IdentifiabilityStatus::Unique)
    }

    pub fn get_migration_context(
        &self,
        shard: ShardId,
    ) -> Result<MigrationContext, EpistemicError> {
        self.migration_registry
            .get(&shard)
            .cloned()
            .ok_or(EpistemicError::ExecutionFailure(
                "Shard untracked".into(),
            ))
    }

    fn compute_posterior_overlap(&self, _shard: ShardId) -> Result<f64, EpistemicError> {
        // placeholder: in full system this is KL / variational overlap
        Ok(0.5)
    }
}
