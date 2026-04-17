# Studio Smoke Checklist

Run this before tagging a release:

1. Sync `default.project.json` into Roblox Studio with Rojo.
2. Confirm the package loads from `ReplicatedStorage.Packages.PathfindingPlus`.
3. Start play mode and watch the single-agent corridor NPC reach its goal.
4. Confirm the blocked-path demo re-routes after the obstacle toggles in front of the agent.
5. Confirm the crowd demo does not repath every NPC on the same frame and that agents spread around the shared goal.
6. Stop one navigator manually and confirm `Cancelled` fires without affecting the others.
7. Force a bad goal or remove a humanoid and confirm `Failed` fires with a useful reason.
