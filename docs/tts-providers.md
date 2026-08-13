# TTS providers, models, and voices

Lazy Reader can speak with either local Piper or hosted OpenRouter TTS.

The important rule: OpenRouter `voice` values are model-specific. A voice that
works for one model can fail for another model. When changing
`services.lazy-reader.ttsModel`, also check and update
`services.lazy-reader.ttsVoice`.

## Provider switch

NixOS default:

```nix
services.lazy-reader = {
  ttsProvider = "piper"; # or "openrouter"
  ttsModel = "x-ai/grok-voice-tts-1.0";
  ttsVoice = "eve";
};
```

Runtime override, no rebuild:

```bash
lazy-reader-set-tts piper tts-1 alloy
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 eve
```

Runtime config is written to:

```text
~/.config/lazy-reader/tts.conf
```

It uses strict `KEY=value` lines:

```text
TTS_PROVIDER=openrouter
TTS_MODEL=x-ai/grok-voice-tts-1.0
TTS_VOICE=eve
```

There is no automatic fallback. If OpenRouter is too expensive or unavailable,
switch explicitly to Piper.

## Local Piper

Provider:

```nix
ttsProvider = "piper";
```

Piper uses the existing local model settings:

```nix
modelUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/medium/en_US-ryan-medium.onnx";
modelSha256 = "...";
modelConfigUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/medium/en_US-ryan-medium.onnx.json";
modelConfigSha256 = "...";
speaker = 0;
```

`ttsModel` and `ttsVoice` are ignored when `ttsProvider = "piper"`.

## OpenRouter TTS

Provider:

```nix
ttsProvider = "openrouter";
```

Lazy Reader sends requests to:

```text
https://openrouter.ai/api/v1/audio/speech
```

The request includes:

```json
{
  "model": "x-ai/grok-voice-tts-1.0",
  "input": "Text to speak",
  "voice": "eve",
  "response_format": "mp3",
  "speed": 1.3
}
```

The `speed` field is sent only when `services.lazy-reader.openRouterSpeed` or
`LAZY_READER_OPENROUTER_SPEED` is set. OpenRouter documents native speed as
provider-dependent; unsupported models may ignore it. Use
`services.lazy-reader.playbackSpeed` for guaranteed faster local playback of the
returned audio.

`response_format` defaults to `auto`: Gemini TTS models use `pcm`, and other
OpenRouter TTS models use `mp3`. You can override this with
`services.lazy-reader.openRouterResponseFormat` or
`LAZY_READER_OPENROUTER_RESPONSE_FORMAT`.

OpenRouter returns raw audio bytes. Lazy Reader downloads the response to a
temporary file with 60s timeout, 10s connect timeout, and 2 retries (1s delay),
then classifies HTTP errors for actionable notifications (401/403 = bad key,
429 = rate limit, 5xx = server error). PCM playback assumes the Gemini TTS
format: 24 kHz, signed 16-bit little-endian, mono.

### OpenRouter model and voice presets

Voice IDs are model-specific and can change independently of Lazy Reader. The
generated catalogue is maintained from OpenRouter's public API; refresh it
before relying on it for a new configuration:

```bash
scripts/update-openrouter-tts-providers.sh
```

<!-- BEGIN OPENROUTER_TTS_MODELS -->
### Generated OpenRouter TTS catalogue

Run `scripts/update-openrouter-tts-providers.sh` to populate or refresh this
catalogue. Use `scripts/update-openrouter-tts-providers.sh --check` in a
manual review to detect a stale catalogue without modifying the file.
<!-- END OPENROUTER_TTS_MODELS -->

## Languages

`lazy-reader` speaks English. Non-English text is not supported through
OpenRouter today, and the obvious workarounds do not work:

Kokoro covers exactly eight languages — American and British English, Spanish,
French, Hindi, Italian, Japanese, Chinese — encoded in the voice prefix
(`af_`/`am_`, `bf_`/`bm_`, `ef_`/`em_`, `ff_`, `hf_`/`hm_`, `if_`/`im_`,
`jf_`/`jm_`, `pf_`/`pm_`, `zf_`/`zm_`). **It has no German voice.** The same
holds for the English-only models (`zonos`, `csm-1b`, `orpheus`) and the local
Piper default (`en_US-ryan-medium`).

`x-ai/grok-voice-tts-1.0` advertises 20+ languages with automatic language
detection, and it does — but only on xAI's native API, where `language`
(BCP-47 or `auto`) is a required request field. OpenRouter's `/audio/speech` is
OpenAI-compatible and has no `language` field at all, so grok never receives
one and falls back to English pronunciation. German text sent through it comes
out as German words read with an English phonemizer. Tried in July 2026;
`speed` is likewise ignored by grok on this endpoint. Untested escape hatch:
OpenRouter's `provider` passthrough, `{"provider":{"options":{"xai":{"language":"auto"}}}}`.

Getting German would mean either that passthrough, or a local Piper `de_DE`
voice — but `ttsProvider` is global, so that would route English through Piper
too, at lower quality than Kokoro.

### `lazy-reader switch german`

`lazy-reader switch german` wires up that passthrough end to end: it writes
`LANGUAGE=de` to `~/.config/lazy-reader/lang.conf` (which appends a German
directive to every mode's LLM prompt so the eight modes answer in German) and
points `tts.conf` at `x-ai/grok-voice-tts-1.0`/`eve`. When `LANGUAGE` is a
non-English code and the TTS model is `x-ai/*`, `_speak_openrouter` adds
`{"provider":{"options":{"xai":{"language":"de"}}}}` to the speech request — the
one documented way to hand grok a `language`. `lazy-reader switch english`
reverts to `LANGUAGE=en` and `hexgrad/kokoro-82m`/`af_heart`.

This passthrough is still **untested against the live endpoint** — if xAI ignores
the provider option here too, fall back to a local Piper `de_DE` voice. The LLM
half (German text) works regardless; only the pronunciation depends on grok.

Note that a speech request has a per-model input cap — grok rejects more than
15000 characters, and Kokoro's context is 4096 tokens. `lazy-reader` splits
text on sentence boundaries at `generatedSpeechChunkMaxChars` (default 14000)
before synthesizing, so long selections are spoken as several requests rather
than being silently truncated.

### Known working xAI Grok Voice TTS config

```nix
services.lazy-reader = {
  ttsProvider = "openrouter";
  ttsModel = "x-ai/grok-voice-tts-1.0";
  ttsVoice = "eve";
};
```

Use a voice listed for `x-ai/grok-voice-tts-1.0` in the generated catalogue.
Do not use OpenAI-style voices such as `alloy` with this model.

## Discover models and voices

List OpenRouter speech-output models:

```bash
curl "https://openrouter.ai/api/v1/models?output_modalities=speech" \
  | jq '.data[] | {id, name, pricing, supported_parameters}'
```

Then open the model API page and check `supported_tts_voices`:

```text
https://openrouter.ai/<provider>/<model>/api
```

This helper prints the current voice IDs from the model API pages:

```bash
for model in \
  x-ai/grok-voice-tts-1.0 \
  google/gemini-3.1-flash-tts-preview \
  zyphra/zonos-v0.1-transformer \
  zyphra/zonos-v0.1-hybrid \
  sesame/csm-1b \
  canopylabs/orpheus-3b-0.1-ft \
  hexgrad/kokoro-82m \
  mistralai/voxtral-mini-tts-2603 \
  openai/gpt-4o-mini-tts-2025-12-15
do
  printf '%s: ' "$model"
  curl -s "https://openrouter.ai/$model/api" \
    | perl -ne 'if(/supported_tts_voices\\":\[(.*?)\]/){$x=$1;$x=~s/\\"//g; print "$x\n"; exit}'
done
```

Voice names are provider-specific and may not appear in the Models API
response.

Useful docs:

- OpenRouter TTS guide: https://openrouter.ai/docs/guides/overview/multimodal/tts
- OpenRouter speech API: https://openrouter.ai/docs/api/api-reference/speech/create-audio-speech
- xAI models and Grok Voice TTS voices: https://openrouter.ai/x-ai

## Direct debug request

This checks OpenRouter without Lazy Reader. Do not print or commit the key.

```bash
api_key="$(cat /path/to/openrouter-api-key)"

jq -n \
  --arg model "x-ai/grok-voice-tts-1.0" \
  --arg input "Hello, this is a direct OpenRouter TTS test." \
  --arg voice "eve" \
  '{model:$model,input:$input,voice:$voice,response_format:"mp3"}' \
| curl --fail-with-body --show-error --max-time 30 --location \
  https://openrouter.ai/api/v1/audio/speech \
  -H "Authorization: Bearer $api_key" \
  -H "Content-Type: application/json" \
  -d @- \
  -o /tmp/openrouter-tts-test.mp3

mpv /tmp/openrouter-tts-test.mp3
```

Gemini TTS requires PCM instead of MP3:

```bash
jq -n \
  --arg model "google/gemini-3.1-flash-tts-preview" \
  --arg input "Hello, this is a direct Gemini TTS test." \
  --arg voice "Zephyr" \
  '{model:$model,input:$input,voice:$voice,response_format:"pcm"}' \
| curl --fail-with-body --show-error --max-time 30 --location \
  https://openrouter.ai/api/v1/audio/speech \
  -H "Authorization: Bearer $api_key" \
  -H "Content-Type: application/json" \
  -d @- \
  -o /tmp/openrouter-tts-test.pcm

mpv --demuxer=rawaudio \
  --demuxer-rawaudio-format=s16le \
  --demuxer-rawaudio-rate=24000 \
  --demuxer-rawaudio-channels=1 \
  /tmp/openrouter-tts-test.pcm
```

If this fails, the response body should explain the issue, usually one of:

- invalid voice for the selected model
- invalid model slug
- missing or invalid API key
- insufficient OpenRouter credits
- rate limit or provider outage

## Runtime checks

Show current runtime override:

```bash
cat ~/.config/lazy-reader/tts.conf
```

Switch to Grok voice:

```bash
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 eve
echo "Hello from Grok TTS." | lazy-reader --stdin start
```

Switch back to local Piper:

```bash
lazy-reader-set-tts piper tts-1 alloy
echo "Hello from Piper." | lazy-reader --stdin start
```
