#!/usr/bin/env bash

read_selection() {
  local selected=""

  if command -v wl-paste >/dev/null 2>&1; then
    selected="$(wl-paste --no-newline --primary 2>/dev/null || true)"
    if [[ -z "${selected//[[:space:]]/}" ]]; then
      selected="$(wl-paste --no-newline 2>/dev/null || true)"
    fi
  fi

  printf '%s' "$selected"
}

read_stdin_text() {
  if [[ -t 0 ]]; then
    return 1
  fi

  cat
}

read_input_text() {
  local input_source="${1:-selection}"

  case "$input_source" in
    selection)
      read_selection
      ;;
    stdin)
      read_stdin_text
      ;;
    *)
      return 1
      ;;
  esac
}

trim_leading_whitespace() {
  local text="$1"

  while [[ -n "$text" ]]; do
    case "${text:0:1}" in
      [[:space:]])
        text="${text:1}"
        ;;
      *)
        break
        ;;
    esac
  done

  printf '%s' "$text"
}

trim_trailing_whitespace() {
  local text="$1"

  while [[ -n "$text" ]]; do
    case "${text: -1}" in
      [[:space:]])
        text="${text:0:${#text}-1}"
        ;;
      *)
        break
        ;;
    esac
  done

  printf '%s' "$text"
}

trim_surrounding_whitespace() {
  local text="$1"

  text="$(trim_leading_whitespace "$text")"
  text="$(trim_trailing_whitespace "$text")"

  printf '%s' "$text"
}

trim_text() {
  local text="$1"
  local max_chars="$2"

  if (( ${#text} > max_chars )); then
    text="${text:0:max_chars}"
  fi

  printf '%s' "$text"
}

find_paragraph_boundary() {
  local text="$1"
  local len="${#text}"
  local last=0
  local i
  local j
  local char

  for ((i = 0; i < len; i++)); do
    if [[ "${text:i:1}" != $'\n' ]]; then
      continue
    fi

    j=$((i + 1))
    while (( j < len )); do
      char="${text:j:1}"
      if [[ "$char" == $'\n' ]]; then
        last=$((j + 1))
        break
      fi
      if [[ "$char" =~ [[:space:]] ]]; then
        ((j++))
        continue
      fi
      break
    done
  done

  printf '%s' "$last"
}

find_sentence_boundary() {
  local text="$1"
  local len="${#text}"
  local last=0
  local i
  local j
  local next_char

  for ((i = 0; i < len; i++)); do
    case "${text:i:1}" in
      .|!|\?)
        j=$((i + 1))
        while (( j < len )); do
          next_char="${text:j:1}"
          case "$next_char" in
            '"'|"'"|')'|']')
              ((j++))
              ;;
            [[:space:]])
              last=$((j + 1))
              break
              ;;
            *)
              break
              ;;
          esac
        done

        if (( j >= len )); then
          last="$len"
        fi
        ;;
    esac
  done

  printf '%s' "$last"
}

find_last_newline_boundary() {
  local text="$1"
  local len="${#text}"
  local last=0
  local i

  for ((i = 0; i < len; i++)); do
    if [[ "${text:i:1}" == $'\n' ]]; then
      last=$((i + 1))
    fi
  done

  printf '%s' "$last"
}

find_last_whitespace_boundary() {
  local text="$1"
  local len="${#text}"
  local last=0
  local i

  for ((i = 0; i < len; i++)); do
    if [[ "${text:i:1}" =~ [[:space:]] ]]; then
      last=$((i + 1))
    fi
  done

  printf '%s' "$last"
}

choose_reading_chunk_length() {
  local text="$1"
  local max_chars="$2"
  local candidate
  local boundary

  if (( ${#text} <= max_chars )); then
    printf '%s' "${#text}"
    return 0
  fi

  candidate="${text:0:max_chars}"

  for boundary in \
    "$(find_paragraph_boundary "$candidate")" \
    "$(find_sentence_boundary "$candidate")" \
    "$(find_last_newline_boundary "$candidate")" \
    "$(find_last_whitespace_boundary "$candidate")"
  do
    if (( boundary > 0 )); then
      printf '%s' "$boundary"
      return 0
    fi
  done

  printf '%s' "$max_chars"
}

chunk_text_for_reading() {
  local text="$1"
  local max_chars="$2"
  local chunk_len
  local chunk

  text="$(trim_surrounding_whitespace "$text")"

  while [[ -n "$text" ]]; do
    chunk_len="$(choose_reading_chunk_length "$text" "$max_chars")"
    chunk="$(trim_surrounding_whitespace "${text:0:chunk_len}")"

    if [[ -z "$chunk" ]]; then
      chunk="${text:0:max_chars}"
      chunk_len="$max_chars"
    fi

    printf '%s\0' "$chunk"

    if (( chunk_len >= ${#text} )); then
      break
    fi

    text="$(trim_leading_whitespace "${text:chunk_len}")"
  done
}

line_looks_code_like() {
  local line="$1"

  case "$line" in
    *'```'*)
      return 0
      ;;
  esac

  if [[ "$line" == "{" || "$line" == "}" || "$line" == "[" || "$line" == "]" || "$line" == "(" || "$line" == ")" || "$line" == ";" ]]; then
    return 0
  fi

  [[ "$line" =~ ^[[:space:]]{4,} ]] && return 0
  [[ "$line" =~ ^[[:space:]]*\$[[:space:]] ]] && return 0

  case "$line" in
    *'function '*|*'fn '*|*'fn('*|*'class '*|*'def '*|*'import '*|*'export '*|*'const '*|*'let '*|*'var '*|*'return '*|*'SELECT '*|*'INSERT '*|*'UPDATE '*|*'DELETE '*|*'echo '*|*'printf '*|*'=>'*|*'::'*|*'->'*|*':='*|*'#!'*)
      return 0
      ;;
  esac

  if [[ "$line" == *'{'* || "$line" == *'}'* || "$line" == *'['* || "$line" == *']'* || "$line" == *';'* ]]; then
    if [[ "$line" == *'('* || "$line" == *')'* || "$line" == *'='* || "$line" == *'<'* || "$line" == *'>'* ]]; then
      return 0
    fi
  fi

  if [[ "$line" == *'('* || "$line" == *')'* ]] && [[ "$line" == *'='* || "$line" == *'<'* || "$line" == *'>'* || "$line" == *';'* ]]; then
    return 0
  fi

  return 1
}

split_text_into_reading_sections() {
  local text="$1"
  local line
  local section=""
  local section_kind=""
  local line_kind

  text="$(trim_surrounding_whitespace "$text")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "${line//[[:space:]]/}" ]]; then
      if [[ -n "$section" ]]; then
        printf '%s\0%s\0' "$section_kind" "$section"
        section=""
        section_kind=""
      fi
      continue
    fi

    if line_looks_code_like "$line"; then
      line_kind="code"
    else
      line_kind="prose"
    fi

    if [[ -z "$section" ]]; then
      section="$line"
      section_kind="$line_kind"
      continue
    fi

    if [[ "$line_kind" == "$section_kind" ]]; then
      section+=$'\n'"$line"
      continue
    fi

    printf '%s\0%s\0' "$section_kind" "$section"
    section="$line"
    section_kind="$line_kind"
  done <<< "$text"

  if [[ -n "$section" ]]; then
    printf '%s\0%s\0' "$section_kind" "$section"
  fi
}
