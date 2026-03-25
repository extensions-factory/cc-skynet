#!/usr/bin/env bash

skynet_init_log() {
  LOG_DIR="${SKYNET_LOG_DIR:-$HOME/.claude/logs}"
  LOG="$LOG_DIR/skynet-$(date '+%Y-%m-%d').log"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  touch "$LOG" 2>/dev/null || true
}

skynet_log() {
  local tag="$1"
  shift
  skynet_init_log
  [ -n "${LOG:-}" ] || return 0
  [ -w "$LOG_DIR" ] || return 0
  echo "[$(date '+%H:%M:%S')] [$tag] $*" >> "$LOG" 2>/dev/null || true
}
