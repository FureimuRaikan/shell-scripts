#!/usr/bin/bash
while true; do
  xdotool mousemove_relative -- 100 0
  sleep 6
  xdotool mousemove_relative -- -100 0
  sleep 6
done