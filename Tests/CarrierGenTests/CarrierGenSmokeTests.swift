import CarrierGen
import Testing

@Suite struct CarrierGenSmokeTests {
    @Test func moduleLinks() {
        #expect(String(describing: CarrierGen.self) == "CarrierGen")
    }
}
