#!/usr/bin/osacompile -o Patch.app

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

set patchLog to "/tmp/hiragino-patch.log"
set pollInterval to 0.5 -- seconds
set timeoutSeconds to 600 -- 10 minutes

set progress total steps to -1
set progress description to "Patch.app: 実行中..."
set progress additional description to "準備中..."

try
    -- check if TLPATH file exists in Resources (test/portable mode)
    set patchSh to quoted form of (POSIX path of (path to resource "Patch.sh"))
    set useAdminPrivileges to true
    try
        set tlpathFile to POSIX path of (path to resource "TLPATH")
        set tlpathValue to do shell script "cat " & quoted form of tlpathFile & " | tr -d '\\n'"
        set useAdminPrivileges to false
    end try

    -- execute shell script in background
    if useAdminPrivileges then
        do shell script patchSh & ¬
            space & "&>" & patchLog & space & "&" with administrator privileges
    else
        do shell script "export TLPATH=" & quoted form of tlpathValue & "; " & patchSh & ¬
            space & "&>" & patchLog & space & "&"
    end if

    -- activate the progress bar
    activate

    -- poll log file until Patch.sh finishes
    set maxIterations to timeoutSeconds / pollInterval
    repeat with i from 1 to maxIterations
        delay pollInterval

        -- read the last line of the log
        set lastLine to do shell script "tail -n 1 " & patchLog & " 2>/dev/null || echo ''"
        set progress additional description to lastLine

        -- check for completion
        if lastLine = "+ exit 0" then
            -- success
            set progress additional description to "完了"
            activate
            display alert "完了"
            return
        else if lastLine = "+ exit 1" then
            -- Patch.sh reported failure
            error number -128
        end if
    end repeat

    -- timeout
    error number -128

on error errMsg number errn
    activate
    set plzChkLog to "失敗：ログファイル " & patchLog & " をご確認ください。"
    try
        set lastLines to do shell script "tail -n 3 " & patchLog & " 2>/dev/null || echo '(ログなし)'"
        set progress additional description to lastLines
    end try
    display alert plzChkLog
end try
