#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p data/raw

base="https://archive.org/download/dictionnairedupa00dumuoft"

curl -L -o data/raw/dictionnairedupa00dumuoft_djvu.txt \
	"$base/dictionnairedupa00dumuoft_djvu.txt"

curl -L -o data/raw/dictionnairedupa00dumuoft_orig_jp2.tar \
	"$base/dictionnairedupa00dumuoft_orig_jp2.tar"

mkdir -p data/raw/jp2
tar -xf data/raw/dictionnairedupa00dumuoft_orig_jp2.tar \
	-C data/raw/jp2 --strip-components=1
