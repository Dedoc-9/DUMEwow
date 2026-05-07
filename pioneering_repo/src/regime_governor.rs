You’re at the point where further abstraction stops helping and starts re-describing the same invariants in different coordinate systems. So for “edit file 3 or move on,” the right move is: edit file 3 once to align it with the two things you already introduced (noise geometry + shard migration), then proceed to execution_governor.rs.

Right now regime_governor.rs has two concrete mismatches with your newer design:

It doesn’t actually use NoiseGeometry (so identifiability is floating above the physical model)
Migration state is not coupled to cross-shard geometric consistency (so CEC risk is unmodeled)
adjoint_state exists but doesn’t influence anything (so sensitivity is decorative, not causal)

Here’s a tight corrected version of FILE 3 that makes it consistent with FILE 1 + FILE 2 without introducing new conceptual layers.

FILE 3 — regime_governor.rs (EDITED / CONSISTENT VERSION)
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
What changed (the important part)

This edit does three real structural fixes:

1. MDD is now actually physical

Before: abstract threshold
Now:

local_mdd = noise_geometry.compute_mdd(...)

So identifiability is no longer “belief-space only.”

2. Migration context now affects identifiability (correct coupling)
effective_mdd = local_mdd * ctx.credibility_weight();

This is the correct place for your “settling vs active” semantics:

not in execution
not in noise geometry
but in epistemic trust weighting
3. CEC signal is now explicit (good move)
shard_drift: drift

You were missing a place where “coordinated collapse begins locally but is not yet global.” This is that hook.

Answer to your implicit design question

You asked earlier (implicitly across files):

Should hardware signature / execution drift live in regime_governor or execution_governor?

Now the clean separation is:

regime_governor.rs → epistemic separability (can we distinguish states?)
execution_governor.rs → physical identity (is the observer still the same machine?)

So:

MDD / identifiability = statistical layer
BIH / hardware fingerprint = physical layer
CEC detection = cross-layer correlation
Next file to implement (correct choice)

Now you should move to:

execution_governor.rs

Because that is where you finally close the loop between:

measurement
hardware identity
differential probing (DAI)
observer drift (BIH)
Direct answer to your last design fork

Should hardware signature be part of MigrationContext?

No.

That would mix:

epistemic trust state (migration)
with
physical identity invariants (BIH)

Instead:

MigrationContext = “how much we trust interpretation”
ExecutionGovernor = “whether the thing doing interpretation is still the same physical system”

If you want, next step I can:

design execution_governor.rs so BIH + DAI actually become measurable instead of symbolic, or
compress all 4 files into a single “minimal verifiable kernel” (much closer to something implementable than the current multi-layer abstraction stack).
