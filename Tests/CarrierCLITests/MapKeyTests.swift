import CarrierCore
import CarrierGen
import CarrierTerminal
import TestSupport
import Testing

/// The map key names every node letter, takes its numbers from the rule set,
/// and fits the side panel.
@Suite struct MapKeyTests {
    func screen() throws -> MapScreen {
        let content = try BundledContent.load()
        let network = try NetworkGenerator(content: content).generate(seed: 1994)
        let takeover = try #require(content.objective("takeover"))
        let (state, _) = ContractEngine(content: content).start(seed: 1994, network: network, objective: takeover)
        return MapScreen(state: state, content: content, style: .plain)
    }

    @Test func everyNodeLetterIsExplained() throws {
        let key = try screen().typeKey(width: Columns.panelWidth)
        for type in NodeType.allCases {
            #expect(key.contains { $0.hasPrefix("\(type.mapLetter) \(type.label):") }, "\(type)")
        }
    }

    @Test func theNumbersComeFromTheTuning() throws {
        let map = try screen()
        let network = map.state.rules.tuning.network
        let key = map.typeKey(width: Columns.panelWidth)
        #expect(key.contains("H REPAIR: +\(network.repairIntegrity) INT EACH TICK"))
        #expect(key.contains("R RELAY: +\(network.relayProxy) DEF IN EVERY FIGHT"))
    }

    @Test func theKeyFitsThePanel() throws {
        for line in try screen().typeKey(width: Columns.panelWidth) {
            #expect(line.count <= Columns.panelWidth, "\(line)")
        }
    }
}
