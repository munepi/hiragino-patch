#!/bin/bash

set -e

##
## INITIALIZATION
## ==============================

PROJROOT=${1:?Usage: $0 <project-root-directory>}
PROJROOT=$(cd "${PROJROOT}" && pwd)

## test environment paths
TESTTEMP=${TESTTEMP:-/tmp/hiragino-patch-test}
TESTROOT=${TESTTEMP}/texlive

## TeX Live repository
TLNET_REPO=${TLNET_REPO:-/opt/texlive/repos/tlnet}

## initialize some environment variables
export LANG=C LANGUAGE=C LC_ALL=C

## helper: build beefplate.tex and show embedded fonts
build_beefplate() {
    cd "${PROJROOT}/test"
    rm -f beefplate.pdf beefplate.aux beefplate.log beefplate.dvi
    ptex2pdf -l -u beefplate.tex
    echo ""
    echo "--- pdffonts beefplate.pdf ---"
    pdffonts beefplate.pdf
    cd "${PROJROOT}"
}

## helper: check if a font name pattern is found in beefplate.pdf
check_beefplate_font() {
    local pattern="$1"
    local label="$2"
    if pdffonts "${PROJROOT}/test/beefplate.pdf" | grep -q "${pattern}"; then
        echo "==> OK: ${label}"
    else
        echo "==> FAILED: ${label}"
        exit 1
    fi
}

##
## INSTALL TeX Live (portable, user permissions)
## ==============================

if [ -d "${TESTROOT}/bin/universal-darwin" ]; then
    echo "==> TeX Live already installed at ${TESTROOT}, skipping installation."
else
    echo "==> Installing TeX Live from ${TLNET_REPO} ..."

    ## deploy the installation profile
    mkdir -p "${TESTTEMP}"
    sed -e "s,@@TESTTEMP@@,${TESTTEMP},g" \
        "${PROJROOT}/test/test-current.profile.in" > "${TESTTEMP}/texlive.profile"

    ## run TeX Live installer with the profile
    "${TLNET_REPO}/install-tl" \
        --profile "${TESTTEMP}/texlive.profile" \
        --repository "${TLNET_REPO}"

    echo "==> Installing collection-langjapanese ..."
    export PATH="${TESTROOT}/bin/universal-darwin:${PATH}"
    tlmgr install collection-langjapanese
fi

## set PATH
export PATH="${TESTROOT}/bin/universal-darwin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
export TLPATH="${TESTROOT}/bin/universal-darwin"

##
## 1. CLI PRE: verify HaranoAji is the default
## ==============================

echo ""
echo "========================================"
echo "  1. CLI PRE: HaranoAji should be default"
echo "========================================"

build_beefplate
check_beefplate_font 'HaranoAji' "HaranoAji fonts embedded (before CLI patch)"

##
## 2. CLI TEST: run Patch.sh
## ==============================

echo ""
echo "========================================"
echo "  2. CLI TEST: Patch.sh"
echo "========================================"

cd "${PROJROOT}"
bash Patch.sh

echo ""
echo "==> CLI test: Patch.sh exited successfully"

## verify kanjix.map
KANJIXMAP=$(kpsewhich -var-value=TEXMFSYSVAR)/fonts/map/dvipdfmx/updmap/kanjix.map
if grep -qi 'HiraginoSerif\|HiraginoSans' "${KANJIXMAP}"; then
    echo "==> OK: kanjix.map contains Hiragino entries"
else
    echo "==> FAILED: kanjix.map does not contain Hiragino entries"
    exit 1
fi

## verify beefplate.pdf now has Hiragino
build_beefplate
check_beefplate_font 'HiraMinProN\|HiraKakuProN\|HiraMaruProN' \
    "Hiragino fonts embedded (after CLI patch)"

##
## 3. Reset to HaranoAji for GUI test
## ==============================

echo ""
echo "========================================"
echo "  3. Reset kanjiEmbed to haranoaji"
echo "========================================"

updmap-sys --setoption kanjiEmbed haranoaji
echo "==> OK: reset to haranoaji"

##
## 4. GUI PRE: verify HaranoAji is back
## ==============================

echo ""
echo "========================================"
echo "  4. GUI PRE: HaranoAji should be back"
echo "========================================"

build_beefplate
check_beefplate_font 'HaranoAji' "HaranoAji fonts embedded (before GUI patch)"

##
## 5. GUI TEST: run Patch.app
## ==============================

echo ""
echo "========================================"
echo "  5. GUI TEST: Patch.app"
echo "========================================"

APP_PATH="${PROJROOT}/Work/hiragino-patch/Patch.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "E: Patch.app not found at ${APP_PATH}. Run 'make app' first."
    exit 1
fi

## place TLPATH file in Resources for test mode (no admin privileges)
echo "${TESTROOT}/bin/universal-darwin" > "${APP_PATH}/Contents/Resources/TLPATH"

## clean up previous log
PATCHLOG="/tmp/hiragino-patch.log"
rm -f "${PATCHLOG}"

## run the app and wait for it to finish
open -W "${APP_PATH}"

## check result from log
if [ -f "${PATCHLOG}" ] && tail -n 5 "${PATCHLOG}" | grep -q '+ exit 0'; then
    echo "==> GUI test: Patch.app exited successfully"
else
    echo "==> GUI test: FAILED"
    echo "    See ${PATCHLOG} for details."
    exit 1
fi

## verify kanjix.map
if grep -qi 'HiraginoSerif\|HiraginoSans' "${KANJIXMAP}"; then
    echo "==> OK: kanjix.map contains Hiragino entries (after GUI patch)"
else
    echo "==> FAILED: kanjix.map does not contain Hiragino entries (after GUI patch)"
    exit 1
fi

## verify beefplate.pdf now has Hiragino
build_beefplate
check_beefplate_font 'HiraMinProN\|HiraKakuProN\|HiraMaruProN' \
    "Hiragino fonts embedded (after GUI patch)"

## clean up test artifacts
rm -f "${PROJROOT}/test/beefplate.pdf" "${PROJROOT}/test/beefplate.aux" \
      "${PROJROOT}/test/beefplate.log" "${PROJROOT}/test/beefplate.dvi"

echo ""
echo "========================================"
echo "  All tests passed!"
echo "========================================"
