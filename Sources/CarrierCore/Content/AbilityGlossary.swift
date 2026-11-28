/// The ability keywords, for a frontend's key or HELP.
public enum AbilityGlossary {
    public static let entries: [(keyword: String, meaning: String)] = [
        ("ATK", "DAMAGE TO THE CURRENT LAYER"),
        ("DEF", "BLOCKS ICE DAMAGE THIS TURN"),
        ("KERNEL", "DAMAGE ONLY THE KERNEL TAKES"),
        ("DRAW", "DRAW CARDS"),
        ("TRACE", "MOVES THE TRACE METER"),
        ("CYC", "CYCLES: WHAT CARDS COST"),
        ("RAM", "A DAEMON'S SHARE OF YOUR RAM"),
        ("/TURN", "A DAEMON DOES IT EVERY TURN"),
        ("PROBE", "SHOWS WEAK AND RESIST TAGS"),
        ("THORNS", "HITS BACK WHEN ICE ATTACKS"),
        ("MUTE", "CUTS ICE TRACE THIS TURN"),
        ("CLEAN", "DELETES MALWARE"),
        ("XFER", "SPEEDS A FILE TRANSFER"),
        ("ONCE", "ONCE PER FIGHT"),
        ("SPENT", "GONE FROM THE DECK AFTER USE"),
        ("NOISE", "RAISES ALERT"),
        ("DEAD", "CANNOT BE PLAYED"),
    ]
}
