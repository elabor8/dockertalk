#!/bin/bash

pandoc -s -o README.html \
  --self-contained \
  -f markdown_github \
  -c support/readme-style.css \
  --template support/readme-template.html \
  -V "pagetitle:Docker Talk" "README.md"
