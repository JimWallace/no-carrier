import CarrierCore
import Testing

@Suite struct CarrierVersionTests {
    @Test func versionIsSemantic() {
        let parts = CarrierVersion.current.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
