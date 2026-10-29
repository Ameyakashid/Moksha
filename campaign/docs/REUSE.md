# Reuse and provenance

## Integrated

- **MOKSHA recovered Oct23 source**: approved controller, damage/contact pipeline, physical cargo, ladders/lifts, sentinel/listener/sentry/Warden, optional sight/sonar, reusable world scenes and authored original scenery assets. Original archive is preserved outside this working project; original source is first commit. Asset paths/provenance are documented in `campaign/presentation/README.md` and `campaign/assets/PROVENANCE.md` where provided.
- **Beehave blackboard**, MIT ©2023 bitbrain, pinned v2.9.2 commit `f09fdbdd489435c32989fed75b3d02ac69be9100`. `campaign/vendor/beehave/blackboard.gd` is actually used for live objective completion facts and build context. Its upstream license, exact source URLs/hashes and narrow compatibility adaptations are in `LICENSE`/`SOURCE.md` beside it. The rest of Beehave is not bundled, and no Beehave behavior tree is claimed used.
- New campaign scenes instantiate the already-shipped Godot physical modules rather than substitute a movement template. Captain policies use the same approved shared controller/contact interfaces, with new attack resources and input decisions.

## Researched, not integrated

LDtk importer (modern MIT Godot4 authoring), Phantom Camera, Kenney CC0 packs and other templates were evaluated. They are not bundled or claimed installed merely because researched. Existing editable scene/data modules avoid an unverified importer dependency.

`morluto/rea` is MIT reverse-engineering tooling, not a ready-made game engine/controller or a license to distribute a commercial game's extracted art/code. No commercial decompilation/ripped assets were used. The Dead Cells influence is connected movement/combat design, not copied source/assets; The Ascent influence is the cyberpunk direction, not its textures or models.
