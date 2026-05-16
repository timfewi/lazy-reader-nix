#!/usr/bin/env bash

play_audio() {
  local audio_file="$1"
  local audio_format="${2:-auto}"

  case "$PLAYER" in
    mpv)
      if [[ "$audio_format" == "pcm" ]]; then
        mpv --no-terminal --really-quiet --audio-display=no --demuxer=rawaudio --demuxer-rawaudio-format=s16le --demuxer-rawaudio-rate=24000 --demuxer-rawaudio-channels=1 --speed="$PLAYBACK_SPEED" "$audio_file" &
      else
        mpv --no-terminal --really-quiet --audio-display=no --speed="$PLAYBACK_SPEED" "$audio_file" &
      fi
      PLAYER_PID="$!"
      wait "$PLAYER_PID"
      PLAYER_PID=""
      ;;
    ffplay)
      if [[ "$audio_format" == "pcm" ]]; then
        ffplay -nodisp -autoexit -loglevel error -f s16le -ar 24000 -ac 1 -af "atempo=${PLAYBACK_SPEED}" "$audio_file" &
      else
        ffplay -nodisp -autoexit -loglevel error -af "atempo=${PLAYBACK_SPEED}" "$audio_file" &
      fi
      PLAYER_PID="$!"
      wait "$PLAYER_PID"
      PLAYER_PID=""
      ;;
    *)
      notify "Unsupported audio player: $PLAYER"
      exit 1
      ;;
  esac
}

play_audio_stream() {
  case "$PLAYER" in
    mpv)
      mpv --no-terminal --really-quiet --audio-display=no --speed="$PLAYBACK_SPEED" -
      ;;
    ffplay)
      ffplay -nodisp -autoexit -loglevel error -af "atempo=${PLAYBACK_SPEED}" -i pipe:0
      ;;
    *)
      notify "Unsupported audio player: $PLAYER"
      return 1
      ;;
  esac
}
