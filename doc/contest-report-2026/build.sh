#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
name='01-作品说明文档+为了看Miku演唱会特前来拿奖金'
xelatex -interaction=nonstopmode -halt-on-error -output-directory=.build -jobname="$name" report.tex
xelatex -interaction=nonstopmode -halt-on-error -output-directory=.build -jobname="$name" report.tex
cp ".build/$name.pdf" "$name.pdf"
