#!/usr/bin/env bash
#
# The MIT License (MIT)
#
# Copyright (c) 2015-2016 Thomas "Ventto" Venriès <thomas.venries@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
usage() {
    echo -e "Usage: mons [OPTION]...

Options can not be used in conjunction.
If no argument, prints plugged monitor ID list.

Information:
  -h:\tPrints this help and exits.
  -v:\tPrints version and exits.

Two monitors:
  -o:\tPreferred monitor only.
  -s:\tSecond monitor only.
  -d:\tDuplicates.
  -e:\tExtends [ top | left | right | bottom ].

More monitors:
  -O:\tEnables only the selected monitor ID.
  -S:\tEnables only two monitors [MON1,MON2:P],
     \tMON1 and MON2 are monitor IDs,
     \tP takes the value [R] right or [T] top for the MON2's placement."
}

version() {
    echo -e "Mons 0.1
Copyright (C) 2016 Thomas \"Ventto\" Venries.\n

License MIT: <https://opensource.org/licenses/MIT>.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.\n"
}

arg_err() {
    usage && exit 2
}

[ -f "/usr/bin/xrandr" ] && XRANDR="/usr/bin/xrandr"
[ -z "${XRANDR}" -a -f "/bin/xrandr" ] && XRANDR="/bin/xrandr"

enable_mon() {
    ${XRANDR} --display ${DISPLAY} --output ${1} --auto
}

disable_mons() {
    while [ $# -ne 0 ] ; do ${XRANDR} --output ${1} --off ; shift ; done
}

# Find the index of a given monitor in the enabled monitor list.
is_enabled() {
    for last; do true; done
    for i in `seq 0 $(($#-1))`; do [ "$1" == "$last" ] && break || shift ; done
    [ "$i" -ne "$(($#-1))" ] && echo "-1" || echo "$i"
}

arg2xrandr() {
    case $1 in
        left)   echo "--left-of"    ;;
        right)  echo "--right-of"   ;;
        bottom) echo "--below"      ;;
        top)    echo "--above"      ;;
    esac
}

main() {
    local dFlag=false
    local eFlag=false
    local oFlag=false
    local sFlag=false
    local OFlag=false
    local SFlag=false
    local is_flag=false

    OPTIND=1
    while getopts "hvosde:O:S:" opt; do
        case $opt in
            h)  usage && exit ;;
            v)  version && exit ;;
            o)  $is_flag && arg_err
                oFlag=true ; is_flag=true
                ;;
            s)  $is_flag && arg_err
                sFlag=true ; is_flag=true
                ;;
            d)  $is_flag && arg_err
                dFlag=true ; is_flag=true
                ;;
            e)  $is_flag && arg_err
                case ${OPTARG} in left | right | bottom | top) ;; *) arg_err ;; esac
                eArg=$OPTARG
                eFlag=true ; is_flag=true
                ;;
            O)  $is_flag && arg_err
                [[ ! "${OPTARG}" =~ ^[0-9]+ ]] && arg_err
                OArg=$OPTARG
                OFlag=true ; is_flag=true
                ;;
            S)  $is_flag && arg_err
                [[ ! "${OPTARG:0:1}" =~ ^[0-9]+$ ]]    && arg_err
                [[ ! "${OPTARG:2:1}" =~ ^[0-9]+$ ]]    && arg_err
                [[ ! "${OPTARG:4:1}" =~ ^[RT]$ ]]      && arg_err
                [ "${OPTARG:0:1}" == "${OPTARG:2:1}" ] && arg_err
                SArg=$OPTARG
                SFlag=true ; is_flag=true
                ;;
            \?) usage && exit ;;
            :)  usage && exit ;;
        esac
    done

    [ -z "${DISPLAY}" ] && echo "X: server not started."     && exit 1
    [ -z "${XRANDR}" ]  && echo "xrandr: command not found." && exit 1

    local xrandr_out="$(${XRANDR} | grep connect)"

    [ -z "${xrandr_out}" ] && echo "No connected monitor." && exit

    local enabled_out="$(echo "${xrandr_out}" | grep -E "\+[0-9]{1,4}\+[0-9]{1,4}")"
    local mons=( $(echo "${xrandr_out}" | cut -d ' ' -f 1) )
    local plug_mons=( $(echo "${xrandr_out}" | grep ' connect'| cut -d " " -f 1) )
    local disp_mons=( $(echo "${enabled_out}" | cut -d " " -f 1) )

    if [ "$#" -eq 0 ]; then
        local state
        for ((i=0; i < ${#mons[@]}; i++)); do
            if [[ "${plug_mons[@]}" =~ "${mons[$i]}" ]] ; then
                [[ "${disp_mons[@]}" =~ "${mons[$i]}" ]] && state="(enabled)"
                printf "%-3s %-9s %-9s\n" "${i}:" "${mons[$i]}" "$state"
            fi
            state=""
        done
        exit
    fi

    if $oFlag ; then
        if [ "${#plug_mons[@]}" -eq 1 ] ; then
            ${XRANDR} --auto 2>&1 || exit
        else
            if [ "${#disp_mons[@]}" -eq 1 ] ; then
                if [ "${disp_mons[0]}" == "${plug_mons[0]}" ] ; then
                    enable_mon ${plug_mons[0]}
                    exit
                fi
            fi
            idx=$(is_enabled ${disp_mons[@]} ${plug_mons[0]})
            disp_mons=( "${disp_mons[@]:(($idx))}" )
            disable_mons ${disp_mons[@]}
            enable_mon ${plug_mons[0]}
        fi
        exit $?
    fi

    if [ "${#plug_mons[@]}" -eq 1 ] ; then
        echo "Only one monitor detected."
        exit
    fi

    if ( $dFlag || $eFlag || $sFlag ) && [ "${#plug_mons[@]}" -gt 2 ] ; then
        echo "At most two plugged monitors for this option."
        exit
    fi

    if $dFlag ; then
        ${XRANDR} --auto
        ${XRANDR} --output ${plug_mons[1]} --same-as ${plug_mons[0]}
        exit $?
    fi

    if $eFlag ; then
        ${XRANDR} --auto
        ${XRANDR} --output ${plug_mons[1]} $(arg2xrandr $eArg) ${plug_mons[0]}
        exit $?
    fi

    if $sFlag ; then
        if [ "${#disp_mons[@]}" -eq 1 ] ; then
            if [ "${disp_mons[0]}" == "${plug_mons[1]}" ] ; then
                enable_mon ${plug_mons[1]}
                exit
            fi
        fi
        enable_mon ${plug_mons[1]}
        disable_mons ${disp_mons[0]}
        exit
    fi

    if [ "${#plug_mons[@]}" -lt 3 ] ; then
        echo "At least three plugged monitors for this option."
        exit 0
    fi

    if $SFlag ; then
        local mon1="${SArg:0:1}"
        local mon2="${SArg:2:1}"
        local area="${SArg:4:1}"

        if [ "${mon1}" -ge "${#mons[@]}" -o "${mon2}" -ge "${#mons[@]}" ]; then
            echo "One or both monitor IDs do not exist."
            echo "Try without option to get monitor ID list."
            exit 2
        fi
        if [[ ! "${plug_mons[@]}" =~ "${mons[${mon1}]}" || \
            ! "${plug_mons[@]}" =~ "${mons[${mon2}]}" ]] ; then
            echo "One or both monitor IDs are not plugged in."
            echo "Try without option to get monitor ID list."
            exit 2
        fi

        [ "${area}" == "R" ] && area="--right-of" || area="--above"

        idx=$(is_enabled ${disp_mons[@]} ${mons[$mon1]})
        [ $idx -ge 0 ] && unset disp_mons[$(($idx))]
        disp_mons=( "${disp_mons[@]}" )
        idx=$(is_enabled ${disp_mons[@]} ${mons[$mon2]})
        [ $idx -ge 0 ] && unset disp_mons[$(($idx))]
        disp_mons=( "${disp_mons[@]}" )
        disable_mons ${disp_mons[@]}
        "${XRANDR}" --output "${mons[${mon2}]}" "${area}" "${mons[${mon1}]}"
        exit
    fi

    if $OFlag ; then
        if [ "${OArg}" -ge "${#mons[@]}" ] ; then
            echo "Monitor ID '${OArg}' does not exist."
            echo "Try without option to get monitor ID list."
            exit 2
        fi
        if ! [[ "${plug_mons[@]}" =~ "${mons[${OArg}]}" ]] ; then
            echo "Monitor ID '${OArg}' not plugged in."
            echo "Try without option to get monitor ID list."
            exit 2
        fi

        idx=$(is_enabled ${disp_mons[@]} ${mons[${OArg}]})
        [ "$idx" -ge 0 ] && unset disp_mons[$(($idx))]
        disp_mons=( "${disp_mons[@]}" )

        disable_mons ${disp_mons[@]}
        enable_mon ${mons[${OArg}]}
    fi
}

main "$@"
