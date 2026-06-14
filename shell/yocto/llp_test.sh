#!/bin/bash

result=()

function filter_arguments() {
  local filtered=()
  local var
  for var in "$@"; do
    [[ "$var" = -llp* ]] && continue
    filtered+=("$var")
  done
  result=("${filtered[@]}")
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
contains_arg "-llpnetboot" "$@"
netboot_support=$?
echo "${netboot_support}"

filter_arguments "$@"

set -- "${result[@]}"
echo "$@"
