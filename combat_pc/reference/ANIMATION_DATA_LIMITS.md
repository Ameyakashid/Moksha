# Animation evidence and current limits

The official [Dead Cells update30.2 notes](https://dead-cells.com/patchnotes/30) describe a ModHelperSkin outfit and a JSON export of joint tracks across the animation set. That establishes the existence of a useful pose-data source. It does not establish a cross-game reuse license, runtime transition graph, or playback timings.

The public [alivecells reader at c317bad4d39c58da8dfa0e70631018bb595d7e54](https://github.com/N3rdL0rd/alivecells/blob/c317bad4d39c58da8dfa0e70631018bb595d7e54/tracks/tracks2blender.py) interprets an animation-keyed object containing joint names and numeric triplets. No actual versioned tracks JSON was recovered in this study. The reader's unused `fps=24.0` variable cannot establish an original animation frame rate. A sample count would still need verified runtime speed, hold and loop behavior before conversion into seconds.

The tool repository's [licensing note](https://github.com/N3rdL0rd/alivecells/blob/c317bad4d39c58da8dfa0e70631018bb595d7e54/README.md#L7-L11) excludes game assets from its MIT license. A separate official rig kit has an unread license and has not been imported into MOKSHA.

MOKSHA therefore continues to use original wireframe geometry, key poses and timings. The primary developer's published running/attack examples inform qualitative silhouette and pose-to-pose readability. Source declarations inform the action/animation boundary. Neither source establishes the missing v35 state-to-clip table or exact movement/weapon timing. No franchise sprite, model, joint-track file or unlicensed implementation is included.
