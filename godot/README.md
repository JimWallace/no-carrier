# NO CARRIER in Godot

The Godot frontend: a GDExtension written in Swift with
[SwiftGodot](https://github.com/migueldeicaza/SwiftGodot). It opens on the
code-cracking run (addendum 03): the board, the hand, the guesses, the
reward between servers, with keywords in card text bold and explained on
hover. `--mode contract` shows the network map and the battle instead. It
drives the same pure engines as `carrier crack` and `carrier play`, and
holds no rule.

## Playing a crack

Click a card, then a slot, to play it there. Cards marked ON ITS OWN run when
clicked. Click two slots to swap them. A dial has arrows that turn it. GUESS
submits the board; HOLD ends the turn without one. Hover a bold word to see
what it means.

| Path | Holds |
|---|---|
| `project/` | The Godot project. Open this folder in Godot. `bin/` (the built library) and `content/` (a copy of the content JSON) are filled by the build and are not in git. |
| `extension/` | The Swift package that builds `libCarrierGodot`: the components in `Components/` (each takes plain values, so the gallery can show any state), the screens in `Screens/` that compose them, the gallery (`Gallery`) and the root node (`NoCarrierGame`). |
| `scripts/build.sh` | Fetches SwiftGodot, builds the library and copies it and the content into `project/`. |
| `scripts/fetch-swiftgodot.sh` | Fetches the pinned SwiftGodot into `extension/vendor/`. |
| `scripts/gallery.sh` | Saves a screenshot of each component sheet: every UI component in every state, for designing them one at a time. |
| `scripts/smoke.sh` | Loads the project in Godot without a window and checks that the game reaches a fight. CI runs it. |

## Play it on a Mac without building

CI builds the extension for macOS 14 and later, Intel and Apple Silicon.
SwiftGodot cannot run on macOS 13: its signal types use parameter packs in
generic types, which need the Swift runtime that ships with macOS 14.

1. Install Godot 4.7.1, the standard build (not .NET), from
   <https://godotengine.org/download/archive/4.7.1-stable/>.
2. Download the `no-carrier-godot-macos` artifact from the latest
   **Godot frontend** run on the pull request or on `main`, and unzip it.
3. Clear the quarantine flag that macOS puts on a download. In Terminal, in
   the unzipped folder:

   ```bash
   xattr -dr com.apple.quarantine .
   ```

4. In Godot, choose **Import**, pick `project.godot` in that folder, and
   press **Run** (F5).

## Build it yourself

You need Swift 6.4 and Godot 4.7.1. From the repository root:

```bash
godot/scripts/build.sh
```

Then open `godot/project` in Godot. The first import of a fresh project
crashes Godot as it quits (a known issue, in `docs/design/decisions.md`);
open the project again and it runs.

## Options for testing

After `--` on the Godot command line, the game takes options that make a
run repeatable:

| Option | Does |
|---|---|
| `--mode crack\|contract` | The crack run (the default) or a contract. |
| `--server ID` | One crack against that server (`kiosk`, `corporate`, `root`) instead of the run. |
| `--crack-actions play:0:1,guess` | Sends these crack actions first (numbers from 0). Also `use:N`, `swap:A:B`, `turn:SLOT:SYMBOL`, `drop:N`, `hold`, `take:N`, `remove:N`, `skip`, `logout`. |
| `--hover X,Y` | Moves the mouse there after the clicks, so a screenshot shows the tooltip. |
| `--seed N` | Starts the run or the contract at seed `N`. |
| `--actions attack:1,play:0,end` | Sends these actions first. Also `scan:N`, `claim`, `ghost`, `wait`, `take:N`, `skip`, `upgrade:N`, `logout`. |
| `--click X,Y` | Clicks at that point in the window, through Godot's input. Repeatable. |
| `--screenshot out.png` | Saves the window after the clicks, then quits. |
| `--quit` | Quits after the first frame. |
| `--gallery NAME` | Shows one component sheet instead of the game: `cards`, `card-states`, `nodes`, `ice`, `fight-panels`, `bars`, `dialogs`. |

For example, a screenshot of the fight on node 1 at seed 1994:

```bash
godot --path godot/project -- --mode contract --seed 1994 --actions attack:1 --screenshot fight.png
```
