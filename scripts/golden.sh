#!/bin/zsh
# The plugin against in-process MLXServeEngine: seeded separations made on the signed bundle the way Gaea calls it
# (gaea-plugin-check: launch under the launch requirement, configure, prepare, run) and through sam-audio-inproc with the
# plan, request and outputs the worker uses. Each pair of stems must be byte for byte the same WAV, and each the mixture's
# length.
#
#   scripts/golden.sh <out-dir>     (after scripts/build-plugin.sh)
#
# Cases: both stems for "speech"; the target alone with untrimmed mixed-case text; "music" with two spans.
set -uo pipefail
ROOT=${0:A:h:h}
cd $ROOT
OUT=${1:?out dir}; mkdir -p $OUT
B=$ROOT/dist/sam-audio.gaeaplugin
MIX=$ROOT/scripts/fixtures/mixture.wav
MODELS=${CHECK_MODELS_ROOT:-/Volumes/DEV_VOL1/Models/Models}
SWIFTPM=(-c release --build-system swiftbuild)
xcrun swift build $SWIFTPM --product sam-audio-inproc > /dev/null && xcrun swift build -c release --product gaea-plugin-check > /dev/null
INPROC=$(xcrun swift build $SWIFTPM --show-bin-path)/sam-audio-inproc; CHECK=$(xcrun swift build -c release --show-bin-path)/gaea-plugin-check
LOG=$OUT/golden.log; : > $LOG
pass=0; fail=0
say() { print -r -- "$*" | tee -a $LOG }
FRAMES=$(python3 -c "import wave,sys; print(wave.open(sys.argv[1]).getnframes())" $MIX)

# case <name> <seed> <params json> <stems…>
case_() {
  local name=$1 seed=$2 params=$3; shift 3
  $CHECK $B --operation audio.separate --model sam-audio-base --lane fp16 --params $params --seed $seed --input "audio=$MIX" \
    --models-root "$MODELS" --budget 64000000000 --timeout 900 --session $OUT/$name.gpp > $OUT/$name-gpp.log 2>&1
  $INPROC --mixture $MIX --params $params --seed $seed --models-root "$MODELS" --out-dir $OUT/$name-inproc 2>> $LOG | tail -1 > $OUT/$name-inproc.json
  for stem in "$@"; do
    local g=$(grep -o '"path":"[^"]*'$stem'.wav"' $OUT/$name-gpp.log | head -1 | sed 's/"path":"//; s/"$//; s/\\\//\//g')
    [[ -f $g ]] && cp $g $OUT/$name-gpp-$stem.wav
    local a=$(shasum -a 256 $OUT/$name-gpp-$stem.wav 2>/dev/null | cut -c1-16) b=$(shasum -a 256 $OUT/$name-inproc/$stem.wav 2>/dev/null | cut -c1-16)
    local n=$(python3 -c "import wave,sys; print(wave.open(sys.argv[1]).getnframes())" $OUT/$name-inproc/$stem.wav 2>/dev/null)
    if [[ -n $a && $a == $b && $n == $FRAMES ]]; then pass=$((pass+1)); say "PASS  $name $stem: byte-identical, $n frames, sha256 $a…"
    else fail=$((fail+1)); say "FAIL  $name $stem: $a… / $b…, $n frames (want $FRAMES)"; fi
  done
}

say "# SAM-Audio golden check $(date -u +%FT%TZ)"
case_ speech 42 '{"describe":"speech"}' target residual
case_ target-only 7 '{"describe":"  Speech ","stems":["target"]}' target
case_ music-spans 9 '{"describe":"music","spans":[{"start_s":0.0,"end_s":0.5,"present":true},{"start_s":5.5,"end_s":8.0,"present":true}]}' target residual
say "$pass passed, $fail failed"
[[ $fail == 0 ]]
