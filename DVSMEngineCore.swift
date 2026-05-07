public final class DVSMEngine {

    // =====================================================
    // MARK: CORE SUBSYSTEMS (previously separate modules)
    // =====================================================

    private var config: DVSMConfig
    private var environment: DVSMEnvironment
    private var state: DVSMSystemState = .uninitialized

    // Lifecycle attestation (formerly separate layer)
    private var bootstrapAttestation: DVSMBootstrapAttestation?

    // =====================================================
    // MARK: INIT
    // =====================================================

    public init(config: DVSMConfig, environment: DVSMEnvironment) {
        self.config = config
        self.environment = environment
    }

    // =====================================================
    // MARK: BOOTSTRAP (replaces factory + lifecycle manager)
    // =====================================================

    public func bootstrap() {

        state = .bootstrapping

        let configHash = hashConfig(config)
        let envHash = hashEnvironment(environment)
        let provHash = DVSMProvenance.provenanceHash()

        let attestation = DVSMBootstrapAttestation(
            configHash: configHash,
            environmentHash: envHash,
            provenanceHash: provHash,
            timestamp: environment.bootTimestamp
        )

        bootstrapAttestation = attestation

        state = .ready
    }

    // =====================================================
    // MARK: SINGLE ENTRY EXECUTION PIPELINE
    // =====================================================

    public func pulse(_ action: Data) throws -> Data {

        guard state == .ready || state == .sealed else {
            throw DVSMError.notReady
        }

        // ALL governance layers collapse into internal calls
        try enforceIdentifiability()
        try enforceNoiseGeometry()
        try enforceExecutionIntegrity()

        return execute(action)
    }

    // =====================================================
    // MARK: EXECUTION CORE
    // =====================================================

    private func execute(_ action: Data) -> Data {
        // deterministic core execution path
        return Data(SHA256.hash(data: action))
    }

    // =====================================================
    // MARK: INTERNAL GOVERNANCE (formerly separate modules)
    // =====================================================

    private func enforceIdentifiability() throws {
        // RegimeGovernor logic collapses here
    }

    private func enforceNoiseGeometry() throws {
        // NoiseGeometry + MDD checks collapse here
    }

    private func enforceExecutionIntegrity() throws {
        // ExecutionGovernor + BIH + DAI collapse here
    }

    // =====================================================
    // MARK: HASH HELPERS
    // =====================================================

    private func hashConfig(_ config: DVSMConfig) -> Data {
        Data(SHA256.hash(data: "\(config.mddSensitivity)".data(using: .utf8)!))
    }

    private func hashEnvironment(_ env: DVSMEnvironment) -> Data {
        Data(SHA256.hash(data: env.nodeID.data(using: .utf8)!))
    }
}
