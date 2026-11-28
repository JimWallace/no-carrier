extension GameTools {
    private static let gameID: JSONValue = [
        "type": "string", "description": "The game id that new_contract or new_fight returned, such as g1.",
    ]
    private static let seed: JSONValue = [
        "type": ["string", "integer"],
        "description": "The seed: decimal, or hex with 0x. The same seed gives the same game. Random when omitted.",
    ]
    private static func detail(_ fallback: String) -> JSONValue {
        [
            "type": "string", "enum": ["full", "compact", "none"],
            "description": .string(
                "How much view to return. full: screen, status, map, hand with rules text, deck, legal actions. "
                    + "compact: screen and legal actions. Default: \(fallback)."),
        ]
    }

    /// The tools, in the order `tools/list` gives them.
    package static let definitions: [ToolDefinition] = [
        ToolDefinition(
            name: "new_contract",
            description: """
                Start a contract: a small network to take over node by node, each node a card fight. \
                Objectives: takeover (capture ROOT), exfiltration (copy the TARGET file and JACK OUT, \
                quietly), infiltrate. Returns the game id and the first view.
                """,
            properties: [
                "objective": [
                    "type": "string", "description": "The objective id from objectives.json. Default: takeover.",
                ],
                "seed": seed,
                "view": detail("full"),
            ],
            required: []),
        ToolDefinition(
            name: "new_fight",
            description: """
                Start one sandbox node fight (carrier fight) against a generated machine, with the starter \
                deck. Returns the game id and the first view.
                """,
            properties: [
                "role": [
                    "type": "string", "enum": ["neutral", "sysop", "root"],
                    "description": "The machine. Default: neutral.",
                ],
                "seed": seed,
                "payload": [
                    "type": "integer",
                    "description":
                        "PAYLOAD cards to add to the deck. Default: from tuning.json when the machine has a KERNEL.",
                ],
                "view": detail("full"),
            ],
            required: []),
        ToolDefinition(
            name: "view",
            description: """
                What the player sees now: the phase, the 40-column screen, the status, the map (fogged), \
                the hand with rules text and noise, the ICE telegraph, and the legal actions with their ids.
                """,
            properties: ["game_id": gameID, "detail": detail("full")],
            required: ["game_id"]),
        ToolDefinition(
            name: "act",
            description: """
                Take one action: an id from legal_actions (attack-4, play-2, end, ghost, take-1, skip), \
                or the text a human types (ATTACK 4, BRUTE.EXE, END, GHOST, JACK OUT, SCAN 3, INFO 3, DECK, \
                HELP). Returns status ok, info (a question, nothing changed) or rejected (nothing changed), \
                the new log lines, and the new view.
                """,
            properties: [
                "game_id": gameID,
                "action": ["type": "string", "description": "An action id, or a typed command."],
                "view": detail("compact"),
            ],
            required: ["game_id", "action"]),
        ToolDefinition(
            name: "log",
            description: "The scrolling log of a game, as the terminal shows it.",
            properties: [
                "game_id": gameID,
                "last": ["type": "integer", "description": "How many of the last lines. Default: 40."],
            ],
            required: ["game_id"]),
        ToolDefinition(
            name: "save_replay",
            description: """
                Write the game's replay file (the format of carrier play --record and carrier fight --record), \
                so that carrier replay can play it again.
                """,
            properties: [
                "game_id": gameID,
                "path": [
                    "type": "string",
                    "description":
                        "Where to write it. Default: a name from the kind and seed, in the current directory.",
                ],
            ],
            required: ["game_id"]),
        ToolDefinition(
            name: "list_games",
            description: "The games running in this server: id, kind, seed, phase and action count.",
            properties: [:],
            required: []),
        ToolDefinition(
            name: "end_game",
            description: "Forget a game. Save its replay first if you want it.",
            properties: ["game_id": gameID],
            required: ["game_id"]),
    ]
}
