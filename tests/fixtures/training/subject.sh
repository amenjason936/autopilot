#!/bin/bash
priority() {
  if [ "$1" -gt 10 ]; then printf 'high\n'; else printf 'low\n'; fi
}
can_write() {
  if [ "$1" = admin ]; then return 0; else return 1; fi
}
