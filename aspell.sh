#!/bin/bash

function License {
echo '
 * Author: Christian Chuba
 * LinkedIn: https://www.linkedin.com/in/christian-chuba-32a3331/
 *
 * Description: A spell checking script optimized for C++ or bash scripting
 *          source files.  It filters out language syntax and variable names.
 *          It only parses comments and text strings.  It runs on Linux.
 * Example:
 * aspell.sh check aspell.cxx # it found 3 spelling errors in 'aspell.cxx'
 *  commans
 *  puncuation
 *  warld
 *
 * License: This code is provided under the very permissive, MIT License.
 *          You are free to use, modify, and distribute this code for any purpose,
 echo '
}

function Usage {
    echo
    echo "Usage: $(basename $0) [check | add] <input file>"
    echo "       check :Spellcheck <source code file>"
    echo
    echo "       This optimizes 'aspell' to only process comments and strings in a source file."
    echo "       It only processes comments and text strings.  It ignores language syntax"
    echo "       It uses the file extension to determine whether to favor C++ or shell script rules"
    echo "       C++ uses '#' for preprocessor directives, shell uses that for comments "
    echo
    echo "       add : Add the list of words in {ignore list file} to local dictionary"
    echo
    echo "       <input file name> either C++ source file or a shell script "
}

function AddToDict {
    local line

    while read -r line; do
        if [ "$line" == "" ]; then continue; fi
        echo "{${line}}"
    done < $1
    read -p "About to add this to local dictionary ..."

    while read -r line; do
        if [ "$line" == "" ]; then continue; fi
        #echo "line=${line}"
        echo -e "*${line}\n#" | aspell -a --lang=en_US &>/dev/null;
    done < $1
}

# $1 is always the file name
# $2 is optionally set to 'shell'
function SpellCheck {
    # C++ uses '#' for preprocessor directives, bash uses them for comments
    # We have to choose source file type because they cannot coexist
    # We treat files with ".sh" or no extension as a shell script otherwise it's
    # program source code like C++.

    local mComments
    local mComment
    local mText
    local mTextFilter
    if [[ ("$(echo "$1" | grep '\.sh')" != "") ||
        ("$(echo "$1" | grep '\.')" == "") ]]; then
        mComment="#";    # shell script syntax for comments
        mComments="$(grep "#" $1 | sed -e "s:.*#::")"
        mTextFilter="grep echo $1"  # only checking text in echo commands
    else
        mComment="//"
        mComments="$(grep "//" $1 | sed -e "s:.*//::")"
        mTextFilter="grep -v "^#" $1"  # C++ filter out preprocessor directives
    fi

    # This grep / sed extracts quoted text
    local mText="$(($mTextFilter) | grep \" | sed -e 's/.*"\(.*\)".*/\1/p' | grep .)"

    # This sed removes standard syntax we want to ignore such as punctuation and "%d" found in strings
    # -e "s:'.*'::g", This removes any single quoted text such as "this is 'MyName'"
    # -e "s:\%[b-s]::", This removes formatting directives
    # The rest of the commands remove '\n', '.', '()', ',', and ':'

    local mlist="$(echo "$mComments $mText" | sed -e  "s:'.*': :g" -e "s:\%[b-s]: :g" -e "s:\\\n: :g" -e "s:(): :g" -e "s:\.: :g" -e "s:\,: :g" -e "s/:/ /g")"

    # Use sort to eliminate duplicate words
    mlist=$(echo "$mlist" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    echo "$mlist" | aspell --lang=en_US --list
}

function Aspell {
    # use an associative array to make testing arguments easier
    local fname=""
    declare -A  args
    for i in "$@"; do args["$i"]=1; fname="$i"; done

    # The caller must select either "check" or "add" and an input file
    if [[ (! -n "${args["add"]}" && ! -n "${args["check"]}" ) ||
              (-n "${args["add"]}" && -n "${args["check"]}") ||
        (! -f "$fname") ]]; then
        Usage; exit 0; fi

    if [ -n "${args["check"]}" ]; then SpellCheck $fname; return; fi

    AddToDict $fname  # add contents of this file to a local dictionary
}

Aspell $1 $2

# inspect the list of words in the output, if they are correct then add into local
# dictionary with ... aspell --lang=en_US --add < word_list.txt
