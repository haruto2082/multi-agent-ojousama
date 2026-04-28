#!/bin/sh
# log.sh - colored logging helpers for ojousama scripts.
# Usage: . "$(dirname "$0")/lib/log.sh"
# Honors NO_COLOR env var (https://no-color.org).

if [ -n "${NO_COLOR:-}" ]; then
    _OJ_C_BLUE=""
    _OJ_C_GREEN=""
    _OJ_C_YELLOW=""
    _OJ_C_ORANGE=""
    _OJ_C_RED=""
    _OJ_C_RESET=""
else
    _OJ_C_BLUE=$(printf '\033[34m')
    _OJ_C_GREEN=$(printf '\033[32m')
    _OJ_C_YELLOW=$(printf '\033[33m')
    _OJ_C_ORANGE=$(printf '\033[38;5;208m')
    _OJ_C_RED=$(printf '\033[31m')
    _OJ_C_RESET=$(printf '\033[0m')
fi

log_info()  { printf '%s【伺】%s %s\n' "$_OJ_C_BLUE"   "$_OJ_C_RESET" "$*"; }
log_done()  { printf '%s【済】%s %s\n' "$_OJ_C_GREEN"  "$_OJ_C_RESET" "$*"; }
log_serve() { printf '%s【仕】%s %s\n' "$_OJ_C_YELLOW" "$_OJ_C_RESET" "$*"; }
log_warn()  { printf '%s【警】%s %s\n' "$_OJ_C_ORANGE" "$_OJ_C_RESET" "$*" >&2; }
log_error() { printf '%s【誤】%s %s\n' "$_OJ_C_RED"    "$_OJ_C_RESET" "$*" >&2; }
