# Captivity SFW

Faithful `.capmod` source conversion of the legacy **Captivity SFW** mod.

The legacy archive was compared sprite-by-sprite with Captivity v1.0.5b. All 32 intentional changes are preserved as transparent replacements for the exact Core anatomy sprite assets used by Musca, Orc, Marksman, Zombies 1–3, Death Hound, Fly, Litigant, Abby, Jenny, Jacky, Android, Sunny, Goblin Trapper, Goblin Minor, Zombie Grabber, Head Humper, and Hunter.

The supplied DLL was compared method-by-method with the original v1.0.5b assembly. Its intended **Captivity No Rape** gameplay changes activate directly whenever this pack is enabled:

- enemies cannot start sexual finishers;
- enemy attacks do not tear clothing;
- reaching zero health consumes a heart instead of starting a finisher;
- exhausting all hearts returns the player to the Hub bed;
- the intended 300-point health/stamina capacity is represented as a 3× player-health multiplier.

No extra game-mode selection is required. The CNR rules and transparent anatomy replacements both apply whenever the pack itself is enabled, matching the original mod's intent.

The runtime substitution is reapplied after animation evaluation, so an Animator changing a renderer back to one of the original Core sprites cannot temporarily reveal it.
