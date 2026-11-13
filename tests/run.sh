#!/usr/bin/env bash
# Tests for nest-veil. Uses a throwaway NEST_VEIL_HOME and fake programs, so it
# never touches your real workspaces. The fish tests run only if fish exists.
#   tests/run.sh
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home" NEST_VEIL_HOME="$T/home/.config/nest-veil"
export PATH="$ROOT/bin:$T/fakebin:$PATH" SHELL=/bin/sh
unset NEST_VEIL NEST_VEIL_DIR NEST_VEIL_CHAIN NEST_VEIL_LABEL NEST_VEIL_VARS NEST_VEIL_AUTO NEST_VEIL_OFF \
  CLAUDE_CONFIG_DIR GH_CONFIG_DIR GIT_CONFIG_GLOBAL XDG_CONFIG_HOME
mkdir -p "$HOME/dev/acme/globex/repo" "$HOME/elsewhere" "$T/fakebin"
printf '[user]\n\tname = Private\n\temail = me@private.test\n' > "$HOME/.gitconfig"
for p in brave code firefox; do
  printf '#!/bin/sh\necho "REAL %s $*"\n' "$p" > "$T/fakebin/$p"
  chmod +x "$T/fakebin/$p"
done

pass=0 fail=0
check() { # check <description> <expected> <actual>
  if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
contains() { # contains <description> <needle> <haystack>
  if [[ $3 == *"$2"* ]]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); printf 'FAIL: %s\n  expected to contain: %s\n  actual: %s\n' "$1" "$2" "$3"; fi
}
nv() { nest-veil "$@" 2>&1; }
H=$NEST_VEIL_HOME

# --- creating and setting directories
cd "$HOME/dev/acme"
contains "new" "created workspace acme" "$(nv new acme)"
contains "set" "~/dev/acme -> acme" "$(nv set acme .)"
nv new globex >/dev/null
contains "nested set" "-> globex (nested in acme)" "$(nv set globex ./globex)"
contains "duplicate new fails" "already exists" "$(nv new acme)"
contains "reserved name fails" "not a valid" "$(nv new set)"
contains "unknown workspace" "no workspace named 'nope'" "$(nv nope true)"
check "unknown workspace exit code" 1 "$(nest-veil nope true >/dev/null 2>&1; echo $?)"

# --- variables and inheritance
printf 'NEST_VEIL_COLOR=magenta\nAWS_PROFILE=acme\nAZURE_CONFIG_DIR=$NEST_VEIL_DIR/azure\n' > "$H/acme/env"
printf 'NEST_VEIL_COLOR=cyan\nAWS_PROFILE="globex"\nexport KUBECONFIG=~/kube\nbad line\n' > "$H/globex/env"
out=$(nest-veil globex sh -c 'echo "$NEST_VEIL|$NEST_VEIL_LABEL|$AWS_PROFILE|$AZURE_CONFIG_DIR|$KUBECONFIG|$NEST_VEIL_COLOR|$CLAUDE_CONFIG_DIR"' 2>/dev/null)
check "nested env stacks on parent" \
  "globex|acme/globex|globex|$H/acme/azure|$HOME/kube|cyan|$H/acme/claude" "$out"
contains "bad env line warns" "ignoring 'bad line'" "$(nest-veil globex true 2>&1)"
sed -i '/bad line/d' "$H/globex/env"
check "switching workspaces drops old vars" "acme||" \
  "$(nest-veil globex nest-veil acme sh -c 'echo "$NEST_VEIL|${KUBECONFIG-}|"' 2>/dev/null)"
check "off clears everything" "|1" "$(nest-veil acme nest-veil off sh -c 'echo "${NEST_VEIL-}|$NEST_VEIL_OFF"')"

# --- logins created on first use, in the top-most workspace
check "browser uses parent profile" "REAL brave --user-data-dir=$H/acme/browsers/brave x" "$(nest-veil globex brave x 2>/dev/null)"
check "vscode uses parent data" \
  "REAL code --user-data-dir $H/acme/vscode/data --extensions-dir $H/acme/vscode/extensions ." \
  "$(nest-veil globex code . 2>/dev/null)"
mkdir -p "$H/globex/browsers/brave"
check "own browser profile wins" "REAL brave --user-data-dir=$H/globex/browsers/brave" "$(nest-veil globex brave 2>/dev/null)"
check "firefox gets --profile" "REAL firefox --profile $H/acme/browsers/firefox" "$(nest-veil acme firefox)"

# --- shims
check "shim inside workspace goes through nest-veil" "REAL code --user-data-dir $H/acme/vscode/data --extensions-dir $H/acme/vscode/extensions" \
  "$(nest-veil acme sh -c 'code')"
check "shim outside workspace runs real program" "REAL code hi" "$(PATH="$ROOT/shims:$PATH" code hi)"

# --- git config chain
check "parent identity inherited" "me@private.test" "$(nest-veil globex git config user.email 2>/dev/null)"
nest-veil acme git config --global user.email me@acme.test
check "global write lands in workspace" "me@acme.test" "$(git config -f "$H/acme/gitconfig" user.email)"
check "nested sees parent identity" "me@acme.test" "$(nest-veil globex git config user.email 2>/dev/null)"
nest-veil globex git config --global user.email me@globex.test 2>/dev/null
check "nested override" "me@globex.test" "$(nest-veil globex git config user.email 2>/dev/null)"
check "parent unaffected" "me@acme.test" "$(nest-veil acme git config user.email)"
check "private name still inherited" "Private" "$(nest-veil globex git config user.name 2>/dev/null)"

# --- status
mkdir -p "$H/acme/claude"
st=$(nv)
contains "status lists parent" "  acme             ~/dev/acme" "$st"
contains "status nests child" "    globex         ~/dev/acme/globex" "$st"
contains "status shows shared" "shares: claude<-acme" "$st"

# --- moving, unsetting, errors
mkdir -p "$HOME/dev/globex"
cd "$HOME/dev"
nv unset ./acme/globex >/dev/null
nv set globex ./globex >/dev/null
check "moved out: own identity kept" "me@globex.test" "$(nest-veil globex git config user.email 2>/dev/null)"
contains "moved out: include re-pointed" "path = ~/.gitconfig" "$(cat "$H/globex/gitconfig")"
contains "set moves from other workspace" "moved ~/dev/globex from globex" "$(nv set acme ./globex)"
nv set globex ./globex >/dev/null
contains "unset unknown" "no workspace is set" "$(nv unset /nowhere)"
echo globex > "$H/acme/parent"; echo acme > "$H/globex/parent"
contains "loop detected" "loop in workspace nesting" "$(nv acme true)"
rm "$H/acme/parent" "$H/globex/parent"
echo missing > "$H/globex/parent"
contains "missing parent" "has parent 'missing'" "$(nv globex true)"
rm "$H/globex/parent"
cd "$HOME/dev/acme" && nv set globex ./globex >/dev/null && nv unset "$HOME/dev/globex" >/dev/null

# --- fish integration
if command -v fish >/dev/null; then
  fish_out=$(fish --no-config -i -c "
    source '$ROOT/fish/conf.d/nest-veil.fish'
    cd '$HOME/dev/acme'; echo 1:\$NEST_VEIL_LABEL:\$AWS_PROFILE
    cd globex/repo; echo 2:\$NEST_VEIL_LABEL:\$AWS_PROFILE:(fish_right_prompt | string replace -ra '\e\[[0-9;]*m' '')
    cd '$HOME/dev/acme'; echo 3:\$NEST_VEIL_LABEL:\$AWS_PROFILE
    cd '$HOME/elsewhere'; set -q NEST_VEIL AWS_PROFILE NEST_VEIL_VARS CLAUDE_CONFIG_DIR; or echo 4:cleared
    contains -- '$ROOT/shims' \$PATH; or echo 5:path-clean
    mkdir -p '$HOME/elsewhere/new'; cd '$HOME/elsewhere/new'
    nest-veil set acme . >/dev/null; echo 6:\$NEST_VEIL
    nest-veil unset . >/dev/null; set -q NEST_VEIL; or echo 7:off
  " 2>&1)
  check "fish: enter parent" "1:acme:acme" "$(sed -n 1p <<< "$fish_out")"
  check "fish: enter nested" "2:acme/globex:globex:acme/globex" "$(sed -n 2p <<< "$fish_out")"
  check "fish: back to parent" "3:acme:acme" "$(sed -n 3p <<< "$fish_out")"
  check "fish: leave clears vars" "4:cleared" "$(sed -n 4p <<< "$fish_out")"
  check "fish: leave clears PATH" "5:path-clean" "$(sed -n 5p <<< "$fish_out")"
  check "fish: set applies immediately" "6:acme" "$(sed -n 6p <<< "$fish_out")"
  check "fish: unset applies immediately" "7:off" "$(sed -n 7p <<< "$fish_out")"
  check "fish: explicit workspace survives cd" "acme" \
    "$(nest-veil acme fish --no-config -i -c "source '$ROOT/fish/conf.d/nest-veil.fish'; cd '$HOME/elsewhere'; echo \$NEST_VEIL" 2>&1)"
  check "fish: off survives cd" "none" \
    "$(nest-veil off fish --no-config -i -c "source '$ROOT/fish/conf.d/nest-veil.fish'; cd '$HOME/dev/acme'; set -q NEST_VEIL; and echo \$NEST_VEIL; or echo none" 2>&1)"
else
  echo "(fish not found; skipping fish tests)"
fi

echo "$pass passed, $fail failed"
(( fail == 0 ))
