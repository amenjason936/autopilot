#!/bin/bash
set -eu
. ./subject.sh
case "${1:-all}" in
  boundary) test "$(priority 10)" = high ;;
  access) can_write admin ;;
  all) test "$(priority 10)" = high; can_write admin ;;
  *) exit 64 ;;
esac
