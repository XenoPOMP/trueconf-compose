#!/bin/bash

FILES=$(\
  find data -maxdepth 1 \( ! -name ".gitkeep" \) \
    | sed "s#data/##g" \
    | sed "s#data##g" \
    | sort \
)

for file in $(\
  find data -maxdepth 1 \( ! -name ".gitkeep" \) \
    | sed "s#data/##g" \
    | sort \
); do
  rm -rf ./data/$file
done