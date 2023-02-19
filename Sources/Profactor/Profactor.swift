public struct iCloudDependency: DependencyKey {
    public var upload: @Sendable (Data) async throws -> Void
}
extension iCloudDependency {
    public static let noop: Self = {
        Self.init(upload: { _ in /* */})
    }()
    public static let liveValue: Self = Self.noop
    public static let previewValue: Self = Self.noop
    public static let testValue: Self = Self.noop
}
extension DependencyValues {
  /// A dependency that exposes an ``UserDefaults.Dependency`` value that you can use to read and
  /// write to `UserDefaults`.
  public var iCloud: iCloudDependency {
    get { self[iCloudDependency.self] }
    set { self[iCloudDependency.self] = newValue }
  }
}


//
//
//public struct KeychainDependency: DependencyKey {
//    public typealias Key = Tagged<Self, String>
//    public var saveData: @Sendable (Data, Key) async throws -> Void
//    public var loadData: @Sendable (Key) async throws -> Data?
//}
//extension KeychainDependency {
//    public static let noop: Self = {
//        Self.init(
//            saveData: { _, _ in },
//            loadData: { _ in nil }
//        )
//    }()
//    public static let liveValue: Self = {
//        Self.init(
//            saveData: { _, _ in },
//            loadData: { _ in nil }
//        )
//    }()
//    public static let previewValue: Self = Self.noop
//    public static let testValue: Self = {
//        Self.init(
//            saveData: unimplemented("\(Self.self).saveData"),
//            loadData: unimplemented("\(Self.self).loadData")
//        )
//    }()
//}
//extension DependencyValues {
//  public var keychain: KeychainDependency {
//    get { self[KeychainDependency.self] }
//    set { self[KeychainDependency.self] = newValue }
//  }
//}


public struct ProfileSnapshotPersistenceDependency: DependencyKey {
    public typealias Key = Tagged<Self, String>
    public var saveProfileSnapshot: @Sendable (ProfileSnapshot) async throws -> Data
    public var loadProfileSnapshot: @Sendable () async throws -> ProfileSnapshot?
}
//public func saveFactorSourceSecret(
//    _ secret: FactorSource.Secret,
//    forFactorSourceID id: FactorSource.ID
//) async throws {
//    try await self.saveData(secret.rawRepresentation, KeychainDependency.Key.init(rawValue: id.uuidString))
//}
internal let profileSnapshotKey = "profileSnapshotKey"
extension ProfileSnapshotPersistenceDependency {
    public static let noop: Self = {
        Self.init(
            saveProfileSnapshot: { _ in Data() },
            loadProfileSnapshot: { nil }
        )
    }()
    public static let liveValue: Self = {
        @Dependency(\.userDefaults) var userDefaults
        return Self.init(
            saveProfileSnapshot: { profileSnapshot in
                @Dependency(\.encode) var encode
                let data = try encode(profileSnapshot)
                try await userDefaults.set(data, forKey: profileSnapshotKey)
                return data
            },
            loadProfileSnapshot:  {
                @Dependency(\.decode) var decode
                guard let data = try await userDefaults.data(forKey: profileSnapshotKey) else {
                    return nil
                }
                return try decode(ProfileSnapshot.self, from: data)
            })
    }()


    public static let previewValue: Self = Self.noop
    public static let testValue: Self = {
        Self.init(
            saveProfileSnapshot: unimplemented("\(Self.self).saveProfileSnapshot"),
            loadProfileSnapshot: unimplemented("\(Self.self).loadProfileSnapshot")
        )
    }()
}
extension DependencyValues {
  public var profileSnapshotPersistence: ProfileSnapshotPersistenceDependency {
    get { self[ProfileSnapshotPersistenceDependency.self] }
    set { self[ProfileSnapshotPersistenceDependency.self] = newValue }
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

public final actor ProfileStorage: Sendable, GlobalActor {
    @Dependency(\.profileSnapshotPersistence) var profileSnapshotPersistence
    @Dependency(\.iCloud) var iCloud
    
//    private let appPreferencesChannel: AsyncBufferedChannel<AppPreferences> = .init()
    private let appPreferencesSubject: AsyncReplaySubject<AppPreferences> = .init(bufferSize: 2)
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
            Task {
                try? await syncStorage()
            }
            emitUpdates()
        }
    }
  
    private init() {
        self.currentNetworkID = .nebunet
        let secret = FactorSource.Secret()
        let newFactorSource = FactorSource(secret: secret)
        self.profile = Profile(factorSource: newFactorSource)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        // Must do this in a separate thread, otherwise we block the concurrent thread pool
        DispatchQueue.global(qos: .userInitiated).async {
            Task {
                await self.load(
                    newFactorSourceIfNeeded: newFactorSource,
                    andItsSecret: secret
                )
                semaphore.signal()
            }
        }
        semaphore.wait()
    }
    
    public func updateProfile(_ newProfile: Profile) async {
        self.profile = newProfile
    }
  
    
    private func load(
        newFactorSourceIfNeeded newFactorSource: FactorSource,
        andItsSecret secret: FactorSource.Secret
    ) async {
        do {
            let snapshot = try await {
                if let loaded = try await profileSnapshotPersistence.loadProfileSnapshot() {
                    return loaded
                } else {
                    // First run, save the new profile and secret
                    try await profileSnapshotPersistence.saveProfileSnapshot(profile.snapshot())
//                    try await keychain.saveFactorSourceSecret(secret, forFactorSourceID: newFactorSource.id)
                    return profile.snapshot()
                }
            }()
            // For first run this might seem unncessary since it resets the same profile, however,
            // it is actually good and needed since it will trigger `didSet`, which triggers emit!
            self.profile = Profile(snapshot: snapshot)
        } catch {
           fatalError("Failed to load profile from keychain, error: \(String(describing: error))")
        }
    }
    
    // MARK: SyncStorage
    private func syncStorage() async throws {
        let snapshot = profile.snapshot()
        let json = try await profileSnapshotPersistence.saveProfileSnapshot(snapshot)
        try await iCloud.upload(json)
    }
    
    // MARK: Emit
    private func emitUpdates() {
        emitNetworkDependentUpdates()
        emitNetworkIndependentUpdates()
    }
    private func emitNetworkIndependentUpdates() {
        print("🎉 emit - useDarkMode: \(profile.appPreferences.useDarkMode)")
//        appPreferencesChannel.send(profile.appPreferences)
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
//        appPreferencesChannel
        appPreferencesSubject
            .removeDuplicates()
//            .buffer(policy: .unbounded)
            .share() // Multicast
            .eraseToAnyAsyncSequence()
            
    }
    
    nonisolated public func accountsCurrentNetwork() -> AnyAsyncSequence<Profile.Network.Accounts> {
        accountsForCurrentNetworkSubject
            .removeDuplicates()
            .share() // Multicast
            .eraseToAnyAsyncSequence()
    }
    
    nonisolated public func personasCurrentNetwork() -> AnyAsyncSequence<Profile.Network.Personas> {
        personasForCurrentNetworkSubject
            .removeDuplicates()
            .share() // Multicast
            .eraseToAnyAsyncSequence()
    }
}
