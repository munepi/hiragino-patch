#!/bin/bash

# This program is licensed under the terms of the MIT License.
#
# Copyright 2017-2026 Munehiro Yamamoto <munepixyz@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -x
set -e

##
## INITIALIZATION
## ==============================

## initialize some environment variables
export LANG=C LANGUAGE=C LC_ALL=C
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
TLPATH=${TLPATH:-}
if [ -z "${TLPATH}" ]; then
    TLPATH=$(
        (
            for ii in /Applications/TeXLive/Library/texlive/ /usr/local/texlive/ ; do
                [ -d "${ii}" ] && echo $ii
            done | head -1 | while read ff ; do
                find "${ff}" -maxdepth 3 -type d -name "*-darwin"
            done | grep -e '/20[0-9][0-9][a-z]*/bin/' | sort | tail -1
        )
          )

    if [ -z "${TLPATH}" ] ; then
        echo E: TeX Live environment not detected
        exit 1
    fi
fi
export PATH=${TLPATH}:${PATH}

## get app's Resources directory
TLRESDIR=$(cd $(dirname "$0"); pwd)

## flag to set up OS-bundled Hiragino fonts with Resources/cjk-gs-support
with_cjkgssupport=${with_cjkgssupport:-1} ## default: 1 (true)

## set Mac OS X version
OSXVERSION=${OSXVERSION:-$(sw_vers -productVersion)}
OSXVERSION=$(echo ${OSXVERSION} | awk -F. '{ OFS=FS; print $1, $2 }') # replace: 10.X.Y -> 10.X

## check some binaries and system-wide TEXMF trees
which kpsewhich || exit 1
which mktexlsr || exit 1
which updmap-sys || exit 1

if [ ! -d $(kpsewhich -var-value=TEXMFLOCAL) ]; then
    echo E: no such directory: TEXMFLOCAL: $(kpsewhich -var-value=TEXMFLOCAL)
    exit 1
fi
if [ ! -d $(kpsewhich -var-value=TEXMFSYSCONFIG) ]; then
    echo E: no such directory: TEXMFSYSCONFIG: $(kpsewhich -var-value=TEXMFSYSCONFIG)
    exit 1
fi
if [ ! -d $(kpsewhich -var-value=TEXMFSYSVAR) ]; then
    echo E: no such directory: TEXMFSYSVAR: $(kpsewhich -var-value=TEXMFSYSVAR)
    exit 1
fi

##
cat<<EOF
----------------------------------------
SETTINGS
----------------------------------------
TLPATH: ${TLPATH}
TLRESDIR: ${TLRESDIR}
with_cjkgssupport: ${with_cjkgssupport}
OSXVERSION: ${OSXVERSION}
TEXMFLOCAL: $(kpsewhich -var-value=TEXMFLOCAL)
TEXMFSYSCONFIG: $(kpsewhich -var-value=TEXMFSYSCONFIG)
TEXMFSYSVAR: $(kpsewhich -var-value=TEXMFSYSVAR)

----------------------------------------
texmf.cnf $(kpsewhich texmf.cnf)
----------------------------------------
$(cat $(kpsewhich texmf.cnf))
EOF

##
## INSTALLATION
## ==============================

## ptex-fontmaps
## NOTE: TL16 already has
##  - ptex-fontmaps/hiragino{,-pron} (for legacy Mac OS X)
##  - ptex-fontmaps/hiragino-elcapitan{,-pron}
HRGNMAPDIR=$(kpsewhich -var-value=TEXMFLOCAL)/fonts/map/dvipdfmx/ptex-fontmaps
mkdir -p ${HRGNMAPDIR}/
cp -a ${TLRESDIR}/ptex-fontmaps/maps/hiragino* ${HRGNMAPDIR}/

## modified/imported a part of lnsysfnt.sh
## https://gist.github.com/munepi/396ef67e3ad051663399
## NOTE: This lnsysfnt() only links Mac OS X bundled Hiragino fonts into
## TEXMFLOCAL/fonts/opentype/cjk-gs-integrate/
lnsysfnt(){
    local HRGNLEGACYDIR=$(kpsewhich -var-value=TEXMFLOCAL)/fonts/opentype/cjk-gs-integrate # screen/hiragino-legacy
    local HRGNDIR=$(kpsewhich -var-value=TEXMFLOCAL)/fonts/truetype/cjk-gs-integrate # screen/hiragino

    mkdir -p ${HRGNDIR}
    pushd ${HRGNDIR}
    rm -f HiraginoSerif*.ttc HiraginoSans*.ttc
    case ${OSXVERSION} in
        10.[0-9]|10.10)
            ## bundled Hiragino OpenType fonts (OS X 10.10 Yosemite or lower versions)
            mkdir -p ${HRGNLEGACYDIR}
            pushd ${HRGNLEGACYDIR}
            rm -f HiraMin*.otf HiraKaku*.otf HiraMaru*.otf

            ln -s "/Library/Fonts/ヒラギノ明朝 Pro W3.otf" HiraMinPro-W3.otf
            ln -s "/Library/Fonts/ヒラギノ明朝 Pro W6.otf" HiraMinPro-W6.otf
            ln -s "/Library/Fonts/ヒラギノ丸ゴ Pro W4.otf" HiraMaruPro-W4.otf
            ln -s "/Library/Fonts/ヒラギノ角ゴ Pro W3.otf" HiraKakuPro-W3.otf
            ln -s "/Library/Fonts/ヒラギノ角ゴ Pro W6.otf" HiraKakuPro-W6.otf
            ln -s "/Library/Fonts/ヒラギノ角ゴ Std W8.otf" HiraKakuStd-W8.otf

            ln -s "/System/Library/Fonts/ヒラギノ明朝 ProN W3.otf" HiraMinProN-W3.otf
            ln -s "/System/Library/Fonts/ヒラギノ明朝 ProN W6.otf" HiraMinProN-W6.otf
            ln -s "/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf"        HiraMaruProN-W4.otf
            ln -s "/System/Library/Fonts/ヒラギノ角ゴ ProN W3.otf" HiraKakuProN-W3.otf
            ln -s "/System/Library/Fonts/ヒラギノ角ゴ ProN W6.otf" HiraKakuProN-W6.otf
            ln -s "/Library/Fonts/ヒラギノ角ゴ StdN W8.otf"        HiraKakuStdN-W8.otf
            popd
            ;;
        10.1[12])
            ## bundled Hiragino OpenType fonts/collections (OS X 10.11 El Capitan/macOS 10.12 Sierra)
            ln -s "/System/Library/Fonts/ヒラギノ明朝 ProN W3.ttc"  HiraginoSerif-W3.ttc
            ln -s "/System/Library/Fonts/ヒラギノ明朝 ProN W6.ttc"  HiraginoSerif-W6.ttc
            ln -s "/Library/Fonts/ヒラギノ丸ゴ ProN W4.ttc"         HiraginoSansR-W4.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc" HiraginoSans-W3.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" HiraginoSans-W6.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc" HiraginoSans-W8.ttc

            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W1.ttc" HiraginoSans-W1.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W2.ttc" HiraginoSans-W2.ttc

            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W0.ttc" HiraginoSans-W0.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc" HiraginoSans-W4.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc" HiraginoSans-W5.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc" HiraginoSans-W7.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W9.ttc" HiraginoSans-W9.ttc
            ;;
        10.1[3-6]|[1-9][0-9].*)
            ## bundled Hiragino OpenType fonts/collections (OS X 10.13 High Sierra)
            ln -s "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"     HiraginoSerif.ttc
            ln -s "/System/Library/Fonts/ヒラギノ丸ゴ ProN W4.ttc"  HiraginoSansR-W4.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W0.ttc" HiraginoSans-W0.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W1.ttc" HiraginoSans-W1.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W2.ttc" HiraginoSans-W2.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc" HiraginoSans-W3.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc" HiraginoSans-W4.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc" HiraginoSans-W5.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" HiraginoSans-W6.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc" HiraginoSans-W7.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc" HiraginoSans-W8.ttc
            ln -s "/System/Library/Fonts/ヒラギノ角ゴシック W9.ttc" HiraginoSans-W9.ttc
            ;;
        *)
            echo E: not supported: ${OSXVERSION}
            return 1
            ;;
    esac
    popd
    return 0
}

cjkgsintg(){
    local cjkgsExtDB=
    local cjkgsopts=

    local CJKGSINTGTEMP=$(mktemp -d) # dummy directory

    ## See cjk-gs-support/README-macos.md in details
    case ${OSXVERSION} in
        10.[0-9]|10.10)
        ;;
        10.11)
            cjkgsExtDB=elcapitan;;
        10.12)
            cjkgsExtDB=sierra;;
        10.1[3-6]|[1-9][0-9].*)
            cjkgsExtDB=highsierra;;
        *)
            echo E: not supported: ${OSXVERSION}
            exit 1
            ;;
    esac
    if [ ! -z "${cjkgsExtDB}" ]; then
        cjkgsopts="--fontdef-add=./cjkgs-macos-${cjkgsExtDB}.dat"
    fi

    ## cleanup all links, which could have been generated in the previous runs
    rm -rf $(kpsewhich -var-value=TEXMFLOCAL)/fonts/opentype/cjk-gs-integrate
    rm -rf $(kpsewhich -var-value=TEXMFLOCAL)/fonts/truetype/cjk-gs-integrate

    ## Then, make links
    pushd ${TLRESDIR}/cjk-gs-support/
    ./cjk-gs-integrate.pl \
        --link-texmf --force --debug \
        --output ${CJKGSINTGTEMP} ${cjkgsopts} || return 1
    popd
    rm -rf ${CJKGSINTGTEMP}
    return 0
}

## remove all links which could have been generated in the bibunsho6 installer runs
rm -rf $(kpsewhich -var-value=TEXMFLOCAL)/fonts/opentype/screen
rm -rf $(kpsewhich -var-value=TEXMFLOCAL)/fonts/opentype/jiyukobo

## link Mac OS bundled fonts into TEXMFLOCAL/fonts/{open,true}type/cjk-gs-integrate/
if [ ${with_cjkgssupport} -eq 1 ]; then
    cjkgsintg || exit 1
else
    lnsysfnt || exit 1
fi

## set hiragino-<Mac OS X flavor>-pron
kanjiEmbed=
case ${OSXVERSION} in
    10.[0-9]|10.10)
        kanjiEmbed=hiragino-pron;;
    10.1[12])
        kanjiEmbed=hiragino-elcapitan-pron;;
    10.1[3-6]|[1-9][0-9].*)
        kanjiEmbed=hiragino-highsierra-pron;;
    *)
        echo E: not supported: ${OSXVERSION}
        exit 1
        ;;
esac
## We run not kanji-config-updmap-sys ${kanjiEmbed} but updmap-sys directly.
mkdir -p $(kpsewhich -var-value=TEXMFSYSCONFIG)/web2c/
echo "kanjiEmbed ${kanjiEmbed}" >$(kpsewhich -var-value=TEXMFSYSCONFIG)/web2c/updmap.cfg

## Finally,
mktexlsr
updmap-sys

## TODO: remove mpost, upmpost from texmf.cnf in TLROOT

echo Finished
exit 0
## end of file
