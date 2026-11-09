# Sandbox

A wide, flat arena for trying enemies one at a time. It replaces the old Sparring Grounds boxing ring.

- The player starts at the west end. A row of switches runs along the floor beside the start, one for every Core enemy in 2.2.2.
- Stand at a switch and press Use: one of that enemy spawns at the far east end and walks in, and a notification says "Spawned: <name>".
- The readable note just right of each switch names its enemy (2.2.2 cannot draw text in the world, so the name is a note you can read with Use).
- There are no normal waves. Wave 1 starts but never fills, so enemies only come from the switches. The switches wake up when Wave 1 begins, about 11 seconds after the stage opens.

Samantha and Pip have their own small stages in the separate `saintpeverell.sandbox-extras` pack ("Sandbox: Samantha" and "Sandbox: Pip"), because 2.2.2 refuses a whole stage when one of its spawners names an enemy from a pack that is not installed.

Made only from what the 2.2.2 release already supports: a Tiled stage, named spawners, Tiled `interaction` switches with Core switch art, Core notes, and a stage script. The ground tiles are the Core yard tiles from `ModSDK/MapTemplates/TiledStage`; the backdrop and props are Core map art.

Not possible with 2.2.2 data alone, so left out:

- a button that clears every enemy (stage scripts have no action that kills or removes enemies);
- name text drawn at a switch (the closest is the readable note beside it).

Validate from the repository root:

```powershell
dotnet run --project Tools/ModSchemaValidator -- . ExampleMods/sandbox
```
