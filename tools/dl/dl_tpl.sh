#!/bin/bash
URL="https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
F=/home/z/my-project/tools/dl/templates.tpz
for i in $(seq 1 40); do
  curl -sL -C - -o "$F" "$URL" && break
  sleep 3
done
touch /home/z/my-project/tools/dl/TPL_DONE
