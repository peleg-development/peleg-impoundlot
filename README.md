# README.md
```md
# peleg-impound (QB/ESX)

**Dependencies:** `ox_lib`, `oxmysql`, (`ox_target` or `qb-target` optional), keys resource (`qb-vehiclekeys` or `mk_vehkeys`).

**Setup:**
1. Import resource and ensure `oxmysql` and `ox_lib` are started.
2. Configure `config.lua` lots, fees, default garage, and keys integration.
3. Start the server; the table `peleg_impound` auto-migrates.

**Officer Command:**
```
/impound [npc|player] [flatbed|tow] [lotId]
```

**Flows:**
- Player: Target at lot → menu of owned impounded → pay base fee → vehicle spawns → keys granted.
- Officer: Target at lot → officer console → pick entry → spawns for nearest player.

**Notes:**
- Framework vehicle table/columns are configurable in `Config.FrameworkTables`.
- NPC tow is simulated and can be extended with true pathing/attach logic.
