import XCTest
import JSONTesting
import BytesMutation
import XCTAssertBytesEqual

@testable import Profactor


final class ProfactorTests: XCTestCase {
    
    func testExample() async throws {
        
        let consumer0Completed = expectation(description: "Consumer 0 completed")
        let consumer1Completed = expectation(description: "Consumer 1 completed")
        
        let ephemeral = UserDefaults.Dependency.ephemeral()
        
        await withDependencies({
            $0.encode = .json
            $0.profileSnapshotPersistence.saveProfileSnapshot = { _ in Data() }
            $0.profileSnapshotPersistence.loadProfileSnapshot = { nil }
            $0.userDefaults = ephemeral
            $0.uuid = .incrementing
        }, operation: {

            Task {
                var received = Set<Bool>()
                for try await appPreferences in ProfileStorage.shared.appPreferences().prefix(2) {
                    print("🔮 consumer 0 received: \(appPreferences.useDarkMode)")
                    received.insert(appPreferences.useDarkMode)
                }
                XCTAssertEqual(received, Set([false, true]))
                consumer0Completed.fulfill()
            }
            
            Task {
                var received = Set<Bool>()
                for try await appPreferences in ProfileStorage.shared.appPreferences().prefix(2) {
                    print("🔮 consumer 1 received: \(appPreferences.useDarkMode)")
                    received.insert(appPreferences.useDarkMode)
                }
                XCTAssertEqual(received, Set([false, true]))
                consumer1Completed.fulfill()
            }
       
            var profileCopy = await ProfileStorage.shared.profile
            profileCopy.appPreferences.useDarkMode = true
            await ProfileStorage.shared.updateProfile(profileCopy)
        })
        
        await waitForExpectations(timeout: 1)
        
    }
}
