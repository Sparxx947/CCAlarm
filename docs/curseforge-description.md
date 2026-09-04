# CCAlarm

**Warns loudly when your healer or tank is crowd-controlled.**

In Mythic+, the second nobody notices the healer is stunned is often the second
that wipes the group. CCAlarm puts it where you cannot miss it: red warning text
at the top centre of your screen, the icons of the active effects with their
remaining time counting down underneath, and a sound.

Healer and tank get **separate sounds**, so you know who was hit without looking.

---

## Why this is harder than it sounds

Detecting crowd control on *other* players is genuinely difficult in Midnight,
and it is worth explaining what CCAlarm does differently.

| Obvious approach | Why it does not work |
|---|---|
| Read the combat log | `COMBAT_LOG_EVENT_UNFILTERED` no longer exists |
| Ask the aura API | Neither `C_UnitAuras` nor the aura data carries any crowd-control field |
| Use `C_LossOfControl` | It reports on **you** only, never on your group |

What remains is a list of spell IDs — and almost every addon in this space
hardcodes one. A hardcoded list is wrong the day a patch ships and stays wrong
until someone updates it.

**CCAlarm learns its list instead.** `LOSS_OF_CONTROL_ADDED` fires whenever
*you* are controlled, and it carries Blizzard's own classification (`locType`)
together with the spell ID. Whatever stuns you in a dungeon also stuns the healer
and the tank in that same dungeon — so the list fills itself as you play and then
covers your whole group.

So the first encounter is not wasted, any unknown harmful aura seen on a healer
or tank is recorded as a **candidate**. `/ccalarm candidates` lists them by name
and ID, ready to be promoted with a single command.

`SCHOOL_INTERRUPT` and `DISARM` are deliberately never learned — neither stops
anyone from moving or healing, and alerting on them would only add noise.

---

## Getting started

1. Copy the `CCAlarm` folder into `Interface/AddOns/`.
2. **Restart WoW completely.** New addons are only read at startup; a `/reload`
   is not enough.
3. Run `/ccalarm test` for a five-second dummy alert, so position and sound are
   right *before* it matters.

There is nothing to configure up front. It works out of the box.

---

## Configuration

Everything is adjustable in game under **Options → AddOns → CCAlarm**, or with
`/ccalarm config`:

| Area | Options |
|---|---|
| Warning text | Font face, size (10–72), colour, outline (none / thin / thick) |
| Icons | Show or hide, size (16–96), maximum count (1–10) |
| Sound | On or off, **separate sounds for healer and tank**, each with a preview button |
| Roles | Healer and tank, individually |
| Zones | Dungeon, arena, open world, raid, battleground |
| Position | Unlock and drag, lock, reset |

While unlocked the frame is tinted so you can grab it even with no alarm running.
The complete anchor is saved, so the display returns to the same spot after a
resolution or UI scale change.

### Sounds

Eight sounds ship with the addon, addressed through `SOUNDKIT` so they need no
files at all. Anything other addons have registered with LibSharedMedia appears
in the list on top of those.

---

## Slash commands

| Command | Effect |
|---|---|
| `/ccalarm config` | Open the options panel |
| `/ccalarm test` | Dummy alert for 5 seconds |
| `/ccalarm unlock` / `lock` | Make the frame draggable |
| `/ccalarm reset` | Reset the position |
| `/ccalarm status` | On/off, watched roles, number of learned spells, active here |
| `/ccalarm list` | All learned spells with their classification |
| `/ccalarm candidates` | Seen but not yet known auras |
| `/ccalarm add <id>` | Add a spell ID |
| `/ccalarm remove <id>` | Remove a spell ID |
| `/ccalarm clear` | Clear the candidate list |
| `/ccalarm on` / `off` | Enable or disable |

German aliases work as well (`einstellungen`, `liste`, `kandidaten`, `dazu`,
`weg`, `leeren`, `an`, `aus`).

---

## No dependencies

CCAlarm ships everything it needs. LibStub, CallbackHandler-1.0 and
LibSharedMedia-3.0 are embedded — **no other addon is required**. Because
LibStub shares libraries, a newer copy from another addon wins automatically,
and fonts or sounds registered by other addons simply show up in the lists as a
bonus. A test in the build pipeline enforces that this stays true.

---

## Limitations

Stated plainly, so nobody relies on something the addon cannot do:

- **The list starts empty.** It fills as effects hit you for the first time, or
  as you promote candidates.
- **Private auras and some encounter mechanics are invisible to addons.** What
  Blizzard hides, this addon cannot see either.
- **Group members only.** For yourself, WoW already draws its own
  loss-of-control display in the middle of your screen.
- **Roles come from the group role assignment** (`UnitGroupRolesAssigned`). A
  member without an assigned role is not watched.

---

## Languages

English and German. English is the primary language; missing keys fall back to
English rather than showing a blank.

---

## Built to be trusted

CCAlarm ships with a test harness that **stubs the WoW API**, so the addon can be
verified without launching the game. It asserts both directions — that the alarm
fires when it should, and that it stays silent when it should: for damage
dealers, unknown spells, sub-second auras, a dead healer, raid instances, and
when switched off. Every push runs those checks, and a release is refused if any
of them fails.

---

**Source, issues and feedback:** [github.com/Sparxx947/CCAlarm](https://github.com/Sparxx947/CCAlarm)
Released under the MIT license.
