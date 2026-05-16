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

OpenRouter returns raw audio bytes. Lazy Reader saves MP3 and plays it through
the configured audio player.

### OpenRouter model and voice presets

These presets came from the OpenRouter model API pages'
`supported_tts_voices` fields. Treat those pages as the source of truth because
voice IDs can change independently of Lazy Reader.

Recommended quick switches:

```bash
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 eve
lazy-reader-set-tts openrouter google/gemini-3.1-flash-tts-preview Zephyr
lazy-reader-set-tts openrouter zyphra/zonos-v0.1-transformer american_female
lazy-reader-set-tts openrouter zyphra/zonos-v0.1-hybrid american_female
lazy-reader-set-tts openrouter sesame/csm-1b conversational_a
lazy-reader-set-tts openrouter canopylabs/orpheus-3b-0.1-ft tara
lazy-reader-set-tts openrouter hexgrad/kokoro-82m af_heart
lazy-reader-set-tts openrouter mistralai/voxtral-mini-tts-2603 en_paul_neutral
lazy-reader-set-tts openrouter openai/gpt-4o-mini-tts-2025-12-15 alloy
```

| Model | Good default | Exact current voice IDs |
| --- | --- | --- |
| `x-ai/grok-voice-tts-1.0` | `eve` | `eve`, `ara`, `rex`, `sal`, `leo` |
| `google/gemini-3.1-flash-tts-preview` | `Zephyr` | `Zephyr`, `Puck`, `Charon`, `Kore`, `Fenrir`, `Leda`, `Orus`, `Aoede`, `Callirrhoe`, `Autonoe`, `Enceladus`, `Iapetus`, `Umbriel`, `Algieba`, `Despina`, `Erinome`, `Algenib`, `Rasalgethi`, `Laomedeia`, `Achernar`, `Alnilam`, `Schedar`, `Gacrux`, `Pulcherrima`, `Achird`, `Zubenelgenubi`, `Vindemiatrix`, `Sadachbia`, `Sadaltager`, `Sulafat` |
| `zyphra/zonos-v0.1-transformer` | `american_female` | `american_female`, `american_male`, `british_female`, `british_male`, `random` |
| `zyphra/zonos-v0.1-hybrid` | `american_female` | `american_female`, `american_male`, `british_female`, `british_male`, `random` |
| `sesame/csm-1b` | `conversational_a` | `conversational_a`, `conversational_b`, `read_speech_a`, `read_speech_b`, `read_speech_c`, `read_speech_d`, `none` |
| `canopylabs/orpheus-3b-0.1-ft` | `tara` | `tara`, `leah`, `jess`, `leo`, `dan`, `mia`, `zac` |
| `hexgrad/kokoro-82m` | `af_heart` | `af_alloy`, `af_aoede`, `af_bella`, `af_heart`, `af_jessica`, `af_kore`, `af_nicole`, `af_nova`, `af_river`, `af_sarah`, `af_sky`, `am_adam`, `am_echo`, `am_eric`, `am_fenrir`, `am_liam`, `am_michael`, `am_onyx`, `am_puck`, `am_santa`, `bf_alice`, `bf_emma`, `bf_isabella`, `bf_lily`, `bm_daniel`, `bm_fable`, `bm_george`, `bm_lewis`, `ef_dora`, `em_alex`, `em_santa`, `ff_siwis`, `hf_alpha`, `hf_beta`, `hm_omega`, `hm_psi`, `if_sara`, `im_nicola`, `jf_alpha`, `jf_gongitsune`, `jf_nezumi`, `jf_tebukuro`, `jm_kumo`, `pf_dora`, `pm_alex`, `pm_santa`, `zf_xiaobei`, `zf_xiaoni`, `zf_xiaoxiao`, `zf_xiaoyi`, `zm_yunjian`, `zm_yunxi`, `zm_yunxia`, `zm_yunyang` |
| `mistralai/voxtral-mini-tts-2603` | `en_paul_neutral` | `en_paul_sad`, `en_paul_neutral`, `en_paul_happy`, `en_paul_frustrated`, `en_paul_excited`, `en_paul_confident`, `en_paul_cheerful`, `en_paul_angry`, `gb_oliver_neutral`, `gb_oliver_sad`, `gb_oliver_excited`, `gb_oliver_curious`, `gb_oliver_confident`, `gb_oliver_cheerful`, `gb_oliver_angry`, `gb_jane_sarcasm`, `gb_jane_confused`, `gb_jane_shameful`, `gb_jane_sad`, `gb_jane_neutral`, `gb_jane_jealousy`, `gb_jane_frustrated`, `gb_jane_curious`, `gb_jane_confident`, `fr_marie_sad`, `fr_marie_neutral`, `fr_marie_happy`, `fr_marie_excited`, `fr_marie_curious`, `fr_marie_angry` |
| `openai/gpt-4o-mini-tts-2025-12-15` | `alloy` | `alloy`, `ash`, `ballad`, `coral`, `echo`, `fable`, `onyx`, `nova`, `sage`, `shimmer`, `verse`, `marin`, `cedar` |

Kokoro uses prefixed voice IDs. Use `af_alloy` for Alloy, not `alloy`.
The full upstream Kokoro voice table is also available in
`https://huggingface.co/hexgrad/Kokoro-82M/raw/main/VOICES.md`.

### Known working xAI Grok Voice TTS config

```nix
services.lazy-reader = {
  ttsProvider = "openrouter";
  ttsModel = "x-ai/grok-voice-tts-1.0";
  ttsVoice = "eve";
};
```

Current xAI Grok Voice TTS voices listed by OpenRouter:

- `eve`
- `ara`
- `rex`
- `sal`
- `leo`

Use one of those values with `x-ai/grok-voice-tts-1.0`. Do not use OpenAI-style
voices like `alloy` with this model.

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
lazy-reader-set-tts openrouter x-ai/grok-voice-tts-1.0 eve
echo "Hello from Grok TTS." | lazy-reader --stdin start
```

Switch back to local Piper:

```bash
lazy-reader-set-tts piper tts-1 alloy
echo "Hello from Piper." | lazy-reader --stdin start
```
