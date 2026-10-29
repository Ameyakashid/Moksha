# Evidence encoding and import isolation

Capture tools supplied JPEG bytes with `.png` names. In this delivery, those files were renamed byte-for-byte to `.jpg`; no pixels were re-encoded or edited. The manifest now names the matching format with the original SHA256 values. `format-renames.json` records the mapping. Raw original captures/manifests remain outside the final project in `moksha-campaign-delivery/visual-qa`. Historical git snapshots also retain their original names.

`.gdignore` excludes review captures from game resource imports. These images document native rendering, not runtime textures.
