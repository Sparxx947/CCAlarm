-- CCSpells.lua -- ERZEUGT von tools/fetch_cc_spells.py, nicht von Hand aendern.
--
-- Saatliste der CC-Zauber. Keine ID ist geraten:
--   * Warcraft Logs sagt, welche Debuffs in der laufenden Saison
--     tatsaechlich von Gegnern auf Spieler gewirkt werden.
--   * Wowhead liefert je Zauber die Mechanik.
--
-- Das Addon LERNT weiter aus LOSS_OF_CONTROL_ADDED; diese Liste ist nur
-- der Startpunkt und ueberschreibt Gelerntes nie.

local ADDON, ns = ...

ns.SEED_SPELLS = {
    [1259365] = "ROOT",  -- Bloodthorn Roots (Rooted, 172x)
    [1241464] = "ROOT",  -- Glacial Tomb (Rooted, 73x)
    [1300684] = "CONFUSE",  -- Hex Muck (Polymorphed, 41x)
    [1238294] = "CONFUSE",  -- Disorienting Screech (Disoriented, 30x)
    [263958] = "STUN",  -- A Knot of Snakes (Stunned, 29x)
    [1201554] = "SLEEP",  -- Seduction (Asleep, 15x)
    [1225638] = "STUN",  -- Loose Sparks (Stunned, 13x)
    [276031] = "FEAR",  -- Pit of Despair (Fleeing, 9x)
    [1288885] = "SILENCE",  -- Tempest Winds (Silenced, 8x)
    [1310361] = "STUN",  -- Tempest Stormshield (Stunned, 5x)
    [272655] = "CONFUSE",  -- Scouring Sand (Disoriented, 3x)
    [1310026] = "CONFUSE",  -- Atomized (Incapacitated, 2x)
    [373593] = "STUN",  -- Frozen Solid (Stunned, 1x)
}

