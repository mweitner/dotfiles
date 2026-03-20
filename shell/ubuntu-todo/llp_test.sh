#!/bin/bash

function filter_arguments() {
  for var in "$@"; do
    shift
    [[ "$var" = -llp* ]] && continue
    set -- "$@" "$var"
  done
  result="$@"
}

function contains_arg() {
  if [ $# -lt 2 ]; then
    return 0
  fi
  local wanted="$1"
  shift
  for arg; do
    if [[ "${wanted}" = "${arg}" ]]; then
      return 1
    fi
  done
  return 0
}
contains_arg "-llpnetboot" $@
netboot_support=$?
echo "${netboot_support}"

filter_arguments $@

set -- "${result}"
echo "$@"
