#!/usr/bin/env bash

cp README.md src/README.md
cd src
if [[ "$1" == "alpha" || "$1" == "beta" ]]; then
  npm publish --tag $1
else
  npm publish
fi
rm README.md
cd ..
