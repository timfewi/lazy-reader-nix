#!/usr/bin/env bash

play_audio() {
  local audio_file="$1"

  case "$PLAYER" in
    mpv)
      mpv --no-terminal --really-quiet --audio-display=no --speed="$SPEED" "$audio_file" &
      PLAYER_PID="$!"
      wait "$PLAYER_PID"
      PLAYER_PID=""
      ;;
    ffplay)
      ffplay -nodisp -autoexit -loglevel error -af "atempo=${SPEED}" "$audio_file" &
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
      mpv --no-terminal --really-quiet --audio-display=no --speed="$SPEED" -
      ;;
    ffplay)
      ffplay -nodisp -autoexit -loglevel error -af "atempo=${SPEED}" -i pipe:0
      ;;
    *)
      notify "Unsupported audio player: $PLAYER"
      return 1
      ;;
  esac
}
