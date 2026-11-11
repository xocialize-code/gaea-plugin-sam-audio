import GaeaPluginKit
import SAMAudioPlugin

// The plugin's worker: SAMAudioPlugin's definition over GPP (GaeaPluginKit). `--manifest <path>` writes manifest.json.
await GaeaPluginMain.run(samAudioPlugin)
