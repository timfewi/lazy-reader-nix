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
  ttsVoice = "Eve";
};
```

Runtime override, no rebuild:

```bash
lazy-reader-set-tts piper tts-1 alloy
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 Eve
```

Runtime config is written to:

```text
~/.config/lazy-reader/tts.conf
```

It uses strict `KEY=value` lines:

```text
TTS_PROVIDER=openrouter
TTS_MODEL=x-ai/grok-voice-tts-1.0
TTS_VOICE=Eve
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
  "voice": "Eve",
  "response_format": "mp3"
}
```

OpenRouter returns raw audio bytes. Lazy Reader saves MP3 and plays it through
the configured audio player.

### Known working xAI Grok Voice TTS config

```nix
services.lazy-reader = {
  ttsProvider = "openrouter";
  ttsModel = "x-ai/grok-voice-tts-1.0";
  ttsVoice = "Eve";
};
```

Current xAI Grok Voice TTS voices listed by OpenRouter:

- `Eve`
- `Ara`
- `Rex`
- `Sal`
- `Leo`

Use one of those values with `x-ai/grok-voice-tts-1.0`. Do not use OpenAI-style
voices like `alloy` with this model.

## Discover models and voices

List OpenRouter speech-output models:

```bash
curl "https://openrouter.ai/api/v1/models?output_modalities=speech" \
  | jq '.data[] | {id, name, pricing, supported_parameters}'
```

Then open the model page on OpenRouter and check its supported voices. Voice
names are provider-specific and may not appear in the Models API response.

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
  --arg voice "Eve" \
  '{model:$model,input:$input,voice:$voice,response_format:"mp3"}' \
| curl --fail-with-body --show-error --location \
  https://openrouter.ai/api/v1/audio/speech \
  -H "Authorization: Bearer $api_key" \
  -H "Content-Type: application/json" \
  -d @- \
  -o /tmp/openrouter-tts-test.mp3

mpv /tmp/openrouter-tts-test.mp3
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
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 Eve
echo "Hello from Grok TTS." | lazy-reader --stdin start
```

Switch back to local Piper:

```bash
lazy-reader-set-tts piper tts-1 alloy
echo "Hello from Piper." | lazy-reader --stdin start
```
