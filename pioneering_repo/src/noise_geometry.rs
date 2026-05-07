// =========================================================================
// DVSM v16.2-X — NOISE GEOMETRY: HIERARCHICAL UNCERTAINTY ESTIMATOR
// =========================================================================

use nalgebra::{DMatrix, DVector};
use crate::regime_governor::MigrationContext;

pub type ShardId = u32;

pub struct NoiseGeometry {
    /// Local shard covariance tensors (mutable per substrate physics)
    local_tensors: std::collections::HashMap<ShardId, CovarianceTensor>,

    /// IMMUTABLE global hyperprior (never relaxed, never mutated)
    global_prior: HyperCovariance,

    /// Consistency tolerance (Wasserstein bound)
    consistency_epsilon: f64,
}

struct CovarianceTensor {
    matrix: DMatrix<f64>,
    drift_mu: DVector<f64>,
    last_update: u64,
}

/// Migration-aware noise estimator
impl NoiseGeometry {

    /// MDD now depends on migration phase weighting
    pub fn compute_mdd(
        &self,
        shard: ShardId,
        adjoint_gain: f64,
        ctx: &MigrationContext
    ) -> f64 {

        let local = self.local_tensors
            .get(&shard)
            .expect("Shard not initialized");

        let base_noise_floor = local.matrix.determinant().sqrt();

        // Migration reduces influence, not global thresholds
        let credibility = ctx.credibility_weight();

        let gain = adjoint_gain.clamp(0.0, 3.0);

        base_noise_floor * (1.0 + gain) * credibility
    }

    /// Global prior NEVER changes — only shard participation is weighted
    pub fn verify_consistency(&self, shard: ShardId) -> Result<(), crate::kernel_core::EpistemicError> {

        let local = self.local_tensors
            .get(&shard)
            .ok_or(crate::kernel_core::EpistemicError::NoiseConsistencyFailure)?;

        let distance = self.global_prior.wasserstein_distance(&local.matrix);

        if distance > self.consistency_epsilon {
            return Err(crate::kernel_core::EpistemicError::NoiseConsistencyFailure);
        }

        Ok(())
    }
}
