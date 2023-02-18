public struct iCloudDependency: DependencyKey {
    public var upload: @Sendable (Data) async throws -> Void
}
extension iCloudDependency {
    public static let noop: iCloudDependency = {
        Self.init(upload: { _ in /* */})
    }()
    public static let liveValue: iCloudDependency = Self.noop
    public static let previewValue: iCloudDependency = Self.noop
    public static let testValue: iCloudDependency = Self.noop
}
extension DependencyValues {
  /// A dependency that exposes an ``UserDefaults.Dependency`` value that you can use to read and
  /// write to `UserDefaults`.
  public var iCloud: iCloudDependency {
    get { self[iCloudDependency.self] }
    set { self[iCloudDependency.self] = newValue }
  }
}
public struct AppPreferences: Sendable, Hashable, Codable {
    public var useDarkMode: Bool
    public init(useDarkMode: Bool = false) {
        self.useDarkMode = useDarkMode
    }
    public static let `default` = Self()
}
public struct ProfileSnapshot: Sendable, Hashable, Codable {
    public let factorSource: FactorSource
    public var appPreferences: AppPreferences
    public var networks: Profile.Networks
    fileprivate init(
        factorSource: FactorSource,
        appPreferences: AppPreferences,
        networks: Profile.Networks
    ) {
        self.factorSource = factorSource
        self.appPreferences = appPreferences
        self.networks = networks
    }
}
public struct FactorSource: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let publicKey: Curve25519.Signing.PublicKey
    public typealias Secret = Curve25519.Signing.PrivateKey
    public init(secret privateKey: Secret) {
        @Dependency(\.uuid) var uuid
        self.id = uuid()
        self.publicKey = privateKey.publicKey
    }
}
public struct Profile: Sendable, Hashable {
    public let factorSource: FactorSource
    public var appPreferences: AppPreferences
    public var networks: Networks
    public init(
        factorSource: FactorSource,
        appPreferences: AppPreferences = .default,
        networks: Networks = .init()
    ) {
        self.factorSource = factorSource
        self.appPreferences = appPreferences
        self.networks = networks
    }
    public init(snapshot: ProfileSnapshot) {
        self.init(
            factorSource: snapshot.factorSource,
            appPreferences: snapshot.appPreferences,
            networks: snapshot.networks
        )
    }
    public func snapshot() -> ProfileSnapshot {
        .init(
            factorSource: factorSource,
            appPreferences: appPreferences,
            networks: networks
        )
    }
}
public enum NetworkIDTag: Hashable {}
public typealias NetworkID = Tagged<NetworkIDTag, UInt8>
extension NetworkID {
    static let nebunet: Self = 11
}
extension Profile {
    public typealias Networks = IdentifiedArrayOf<Network>
    public struct Network: Sendable, Hashable, Codable, Identifiable {
        
        public typealias Accounts = NonEmpty<IdentifiedArrayOf<Account>>
        public typealias Personas = IdentifiedArrayOf<Persona>
        public typealias ID = NetworkID
        
        public let id: ID
        public let accounts: Accounts
        public let personas: Personas
    }
}
extension Profile.Network {
    public struct Account: Sendable, Hashable, Codable, Identifiable {
        public typealias Address = Tagged<Self, String>
        public typealias ID = Address
        public let address: Address
        public var id: ID { address }
    }
    public struct Persona: Sendable, Hashable, Codable, Identifiable {
        public typealias Address = Tagged<Self, String>
        public typealias ID = Address
        public let address: Address
        public var id: ID { address }
    }
}
internal let profileSnapshotKey = "profileSnapshotKey"
extension UserDefaults.Dependency {
    public func loadProfileSnapshot() async throws -> ProfileSnapshot? {
        @Dependency(\.decode) var decode
        guard let data = self.data(forKey: profileSnapshotKey) else {
            return nil
        }
        return try decode(ProfileSnapshot.self, from: data)
    }

    @discardableResult
    public func saveProfileSnapshot(_ profileSnapshot: ProfileSnapshot) async throws -> Data {
        @Dependency(\.encode) var encode
        let data = try encode(profileSnapshot)
        self.set(data, forKey: profileSnapshotKey)
        return data
    }
    
    public func saveFactorSourceSecret(
        _ secret: FactorSource.Secret,
        forFactorSourceID id: FactorSource.ID
    ) async throws {
        self.set(secret.rawRepresentation.description, forKey: id.uuidString)
    }
}


public final actor ProfileStorage: Sendable, GlobalActor {
    @Dependency(\.userDefaults) var keychainClient
    @Dependency(\.iCloud) var iCloud
    
    private let appPreferencesSubject: AsyncReplaySubject<AppPreferences> = .init(bufferSize: 1)
    private let accountsForCurrentNetworkSubject: AsyncReplaySubject<Profile.Network.Accounts> = .init(bufferSize: 1)
    private let personasForCurrentNetworkSubject: AsyncReplaySubject<Profile.Network.Personas> = .init(bufferSize: 1)
    
    public static let shared = ProfileStorage()
    
    private var currentNetworkID: NetworkID {
        didSet {
            emitNetworkDependentUpdates()
        }
    }
    
    public private(set) var profile: Profile {
        didSet {
            print("DID SET PROFILE")
            Task {
                try? await syncStorage()
            }
            emitUpdates()
        }
    }
    public func updateProfile(_ newProfile: Profile) async {
        self.profile = newProfile
    }
  
    private init() {
        self.currentNetworkID = .nebunet
        let secret = FactorSource.Secret()
        let newFactorSource = FactorSource(secret: secret)
        self.profile = Profile(factorSource: newFactorSource)
        Task {
            await load(
                newFactorSourceIfNeeded: newFactorSource,
                andItsSecret: secret
            )
        }
    }
    
    private func load(
        newFactorSourceIfNeeded newFactorSource: FactorSource,
        andItsSecret secret: FactorSource.Secret
    ) async {
        do {
            let snapshot = try await {
                if let loaded = try await keychainClient.loadProfileSnapshot() {
                    return loaded
                } else {
                    // First run, save the new profile and secret
                    try await keychainClient.saveProfileSnapshot(profile.snapshot())
                    try await keychainClient.saveFactorSourceSecret(secret, forFactorSourceID: newFactorSource.id)
                    return profile.snapshot()
                }
            }()
            // For first run this might seem unncessary since it resets the same profile, however,
            // it is actually good and needed since it will trigger `didSet`, which triggers emit!
            self.profile = Profile(snapshot: snapshot)
        } catch {
           fatalError("Failed to load profile from keychain")
        }
    }
    
    // MARK: SyncStorage
    private func syncStorage() async throws {
        let snapshot = profile.snapshot()
        let json = try await keychainClient.saveProfileSnapshot(snapshot)
        try await iCloud.upload(json)
    }
    
    // MARK: Emit
    private func emitUpdates() {
        print("EMIT!")
        emitNetworkDependentUpdates()
        emitNetworkIndependentUpdates()
    }
    private func emitNetworkIndependentUpdates() {
        appPreferencesSubject.send(profile.appPreferences)
    }
    private func emitNetworkDependentUpdates() {
        guard let network = profile.networks[id: currentNetworkID] else {
            return
        }
        accountsForCurrentNetworkSubject.send(network.accounts)
        personasForCurrentNetworkSubject.send(network.personas)
    }
    
    // MARK: AsyncSequence
    nonisolated public func appPreferences() -> AnyAsyncSequence<AppPreferences> {
        appPreferencesSubject
            .removeDuplicates { $0 == $1 }
            .share() // Multicast
            .eraseToAnyAsyncSequence()
    }
    
    nonisolated public func accountsCurrentNetwork() -> AnyAsyncSequence<Profile.Network.Accounts> {
        accountsForCurrentNetworkSubject
            .removeDuplicates { $0 == $1 }
            .share() // Multicast
            .eraseToAnyAsyncSequence()
    }
    
    nonisolated public func personasCurrentNetwork() -> AnyAsyncSequence<Profile.Network.Personas> {
        personasForCurrentNetworkSubject
            .removeDuplicates { $0 == $1 }
            .share() // Multicast
            .eraseToAnyAsyncSequence()
    }
}
