import XCTest
import JSONTesting
import BytesMutation
import XCTAssertBytesEqual

@testable import Profactor


final class ProfactorTests: XCTestCase {
    
    func testExample() async throws {
        let encodesProfile = expectation(description: "Encodes profile")
        
        let consumer0Completed = expectation(description: "Consumer 0 completed")
        let consumer1Completed = expectation(description: "Consumer 1 completed")
        
        let ephemeral = UserDefaults.Dependency.ephemeral()
        
        await withDependencies({
            $0.encode = {
                encodesProfile.fulfill()
                return .json
            }()
            $0.uuid = .incrementing
            $0.userDefaults = ephemeral
        }, operation: {
            let storage = ProfileStorage.shared
            let consumer0Ready = expectation(description: "Consumer 0 ready")
            let consumer1Ready = expectation(description: "Consumer 1 ready")
            Task {
                var received = Set<Bool>()
                consumer0Ready.fulfill()
                for try await appPreferences in storage.appPreferences().prefix(2) {
                    print("consumer0 - appPreferences.useDarkMode: \(appPreferences.useDarkMode)")
                    received.insert(appPreferences.useDarkMode)
                }
                XCTAssertEqual(received, Set([false, true]))
                consumer0Completed.fulfill()
            }
            Task {
                var received = Set<Bool>()
                consumer1Ready.fulfill()
                for try await appPreferences in storage.appPreferences().prefix(2) {
                    print("consumer1 - appPreferences.useDarkMode: \(appPreferences.useDarkMode)")
                    received.insert(appPreferences.useDarkMode)
                }
                XCTAssertEqual(received, Set([false, true]))
                consumer1Completed.fulfill()
            }
            wait(for: [consumer0Ready, consumer1Ready], timeout: 0.01)
            var profileCopy = await storage.profile
            profileCopy.appPreferences.useDarkMode = true
//            Task {
                await storage.updateProfile(profileCopy)
//            }
        })
      
        await waitForExpectations(timeout: 0.5)

    }
}
