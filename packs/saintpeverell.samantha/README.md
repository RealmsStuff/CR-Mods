# Samantha, the boxing kangaroo

An original enemy for Captivity Reloaded Mod API v1, by Saint Peverell. Samantha is a boxing kangaroo animatronic built for prize-fight birthday parties, and she still counts the rounds. The pack uses only official Mod API v1 fields; validate the folder with **Captivity Reloaded > Modding > Captivity Mod Packager > Validate Mod**.

- **Art:** artist-made, painted over Abby's rig layout, with a three-segment tail. The anatomy bones stay in the rig but are never drawn.
- **Movement:** a boxer's guard idle and a shuffle that keeps one foot on the floor; jump and climb are Abby's clips.
- **Attacks:** a stepping jab; a one-two-hook (three hits, the hook knocks back hard); an overhand haymaker thrown from a lunge and a tail kick, both of which knock the player back hard; and a grab.
- **Grab:** four phases. She pins the wrists overhead and punches: jabs, body shots, heavy hooks (which also drain the escape meter), then a wound-up final punch to the stomach whose `pleasure` 100 forces an orgasm. Escaping before the last punch avoids it. The player flinches and winces at each hit and kicks while held.
- **Stage:** she comes from the switch on the `Sandbox: Samantha` stage in the Sandbox Extras pack (`saintpeverell.sandbox-extras`). Press Use at the switch and she walks in from the far end.

Samantha also comes to Furry Entertainment Robotics from wave 3: she joins its Jenny and Sunny spawners at half weight (`spawn.joinCoreSpawners` on `core:enemy/jenny`, game 2.2.3 or later; Sunny is left out because Field Day has a Sunny spawner too, and every FER spawner that offers Sunny also offers Jenny). The 2.2.3 release itself ignores minimum waves on Core stages (fixed by Captivity-Reloaded PR #36), so there she can come from wave 1. Elsewhere she appears only on stages that list her in a spawner, such as `Sandbox: Samantha`.

Attack and AI ranges follow Core FER melee (about 2.5 to 3.3, hips to hips). The grab can be previewed in **Player Animation Preview** (Modded enemies, Paired preview).
