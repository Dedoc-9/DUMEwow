// =========================================================================
// DVSM v16.2-X — NOISE GEOMETRY: HIERARCHICAL UNCERTAINTY ESTIMATOR
// =========================================================================

use nalgebra::{DMatrix, DVector};

pub type ShardId = u32;

pub struct NoiseGeometry {
    /// Level 1: Local Covariance Tensors (Per-Shard Physics)
    local_tensors: std::collections::HashMap<ShardId, CovarianceTensor>,
    /// Level 2: Shared Latent Hyperprior (Global Consistency Boundary)
    global_prior: HyperCovariance,
    /// Tolerance for Wasserstein distance between local and global models
    consistency_epsilon: f64,
}

struct CovarianceTensor {
    matrix: DMatrix<f64>, // Sigma_i
    drift_mu: DVector<f64>, // Mean shift
    last_update: u64,
}

impl NoiseGeometry {
    /// Computes the Sensitivity-Weighted Minimum Detectable Divergence.
    /// MDD = Base_Floor * (1 + Sensitivity_Gain)
    pub fn compute_mdd(&self, shard: ShardId, adjoint_gain: f64) -> f64 {
        let local = self.local_tensors.get(&shard).expect("Shard not initialized");
        let base_noise_floor = local.matrix.determinant().sqrt();
        
        // Asymmetric Scaling: Higher sensitivity widens the window to prevent false alarms,
        // but is capped to prevent adversaries from hiding drift in high-complexity tasks.
        let gain_clamp = adjoint_gain.clamp(0.0, 3.0);
        base_noise_floor * (1.0 + gain_clamp)
    }

    /// Level 3: Cross-Shard Consistency Operator
    /// Uses Wasserstein Distance to ensure local noise isn't being "steered" by an adversary.
    pub fn verify_consistency(&self, shard: ShardId) -> Result<(), crate::kernel_core::EpistemicError> {
        let local = self.local_tensors.get(&shard).ok_or(crate::kernel_core::EpistemicError::NoiseConsistencyFailure)?;
        
        let distance = self.global_prior.wasserstein_distance(&local.matrix);
        
        if distance > self.consistency_epsilon {
            // Detected an "Island of Deception": Local noise geometry is 
            // statistically impossible given the global prior.
            return Err(crate::kernel_core::EpistemicError::NoiseConsistencyFailure);
        }
        Ok(())
    }
}
