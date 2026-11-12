# gaea-plugin-sam-audio

Meta's [SAM-Audio](https://github.com/facebookresearch/sam-audio) base as a [Gaea](https://github.com/xocialize-code/gaea)
plugin: `audio.separate` **by description** (MES Audio 0.1 with RFC 0008, media-engine-spec 0.13.0).

A client names a sound in a few lowercase words — `"speech"`, `"dog barking"`, `"drums"` — and gets it back as `target`,
with everything else as `residual`. Both are 48 kHz mono and the mixture's length.

| | |
|---|---|
| Model | `sam-audio-base`, one lane (`fp16`): 3.5 GB resident + 6.0 GB while running |
| Operation | `audio.separate` with `describe` (required), `stems` (`target`, `residual`), `spans`, `seed` |
| Mixture | up to 30 s, any sample rate; under 5 s is unreliable |
| Works on | general sounds, speech against music, music, drums, bass. Not guitar-like instruments |
| Stems | generated, not filtered (`stem_method: regenerated`): never derive anything by subtraction |
| Watermark | every output carries an AudioSeal watermark (`supports.watermark: audioseal`) |
| Engine package | [xocialize/mlx-sam-audio-swift](https://github.com/xocialize/mlx-sam-audio-swift) 0.2.1, weights [mlx-community/sam-audio-base-swift-fp16](https://huggingface.co/mlx-community/sam-audio-base-swift-fp16) |

## Licence

**The SAM License** (`LICENSE`), for the model, the code that runs it, and so this plugin's bundle. Commercial use is
allowed. It prohibits military, warfare, nuclear, espionage and weapons uses and anything trade controls prohibit, and
allows redistribution only under the same licence with a copy of it. The offer is `accepted_required` and
`user_accept_required`: the operator accepts the terms when enabling it, and each client's user is asked to.

## Requests

```bash
curl -s -H 'MES-Version: 0.1' -H 'Content-Type: application/json' http://localhost:7340/mes/v0/jobs \
  -d '{"operation":"audio.separate","model":"sam-audio-base","inputs":{"audio":{"asset":"<mixture>"}},"params":{"describe":"speech","seed":7}}'
```

- `describe`: 1–200 characters. Short lowercase noun or verb phrases work; sentences do not. It is trimmed and
  lower-cased for the model, and `effective.describe` reports what the model got.
- `spans`: up to 32 of `{start_s, end_s, present}`, where the sound is, or is not, present. They help sounds that come
  and go. A span ending past the mixture's end is refused as `out_of_limits`: Gaea allows one sample, never a clip.
- The same seed gives the same bytes.

## Status

- Built and unit-tested (`swift test`, 6 tests); `manifest.json` generates and validates.
- Signed in CI with Developer ID (team `CFZS6RXUCP`). On the signed bundle, `scripts/check-plugin.sh` passes with the
  GPU job and `scripts/golden.sh` is 5/5 byte-identical to `sam-audio-inproc`.
- Through Gaea 1.6.0 (the first Gaea on media-engine-spec 0.13.0, and this plugin's `minGaea`), MES conformance
  AUDIO-019 to 021 pass: a described separation end to end, spans, and the refusals.
- The bundle carries a copy of the SAM License (`Contents/Resources/LICENSE`), and each release attaches one.

## Build

Written from the [plugin template](https://github.com/xocialize-code/gaea-plugin-demo/blob/main/AUTHORING.md).

```bash
scripts/build-plugin.sh
```

```bash
scripts/check-plugin.sh
```

```bash
scripts/golden.sh dist/golden
```

`CHECK_MODELS_ROOT` names a models folder that holds `mlx-community/sam-audio-base-swift-fp16`.
