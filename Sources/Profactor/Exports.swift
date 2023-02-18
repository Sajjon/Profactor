@_exported import Algorithms
@_exported import AsyncAlgorithms
@_exported import AsyncExtensions
@_exported import Collections
@_exported import Dependencies
@_exported import DependenciesAdditions
@_exported import Foundation
@_exported import IdentifiedCollections
@_exported import NonEmpty
@_exported import Tagged
@_exported import CryptoKit

extension Tagged: Sendable where RawValue: Sendable {}
extension NonEmpty: @unchecked Sendable where Collection: Sendable {}
extension IdentifiedArrayOf: Sendable where Element: Sendable {}

struct ElementDoesNotExist: Swift.Error {}
extension IdentifiedArrayOf {
    public func get(_ id: ID) throws -> Element {
        guard let element = self[id: id] else {
            throw ElementDoesNotExist()
        }
        return element
    }
}

extension Curve25519.Signing.PublicKey: Codable {
    public init(from decoder: Decoder) throws {
        try self.init(rawRepresentation: decoder.singleValueContainer().decode(Data.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container =  encoder.singleValueContainer()
        try container.encode(rawRepresentation)
    }
}

extension Curve25519.Signing.PublicKey: @unchecked Sendable {
    
}
extension Curve25519.Signing.PublicKey: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawRepresentation == rhs.rawRepresentation
    }
    
    
}
extension Curve25519.Signing.PublicKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawRepresentation)
    }
}
