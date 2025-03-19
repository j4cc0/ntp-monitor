#!/bin/bash
# Descr: Very basic ntp-monitoring script
# Usage: ntp-monitor.sh [track|graph] <ip-address> [ip-address] [...]
# Author: Jacco van Buuren
# License: BSD 3-clause

MODE="track"
RED="#FF0000"
BLUE="#0000FF"

COLOFF="$RED"
COLJIT="$BLUE"

warn() {
        echo "[!] $@" >&2
        return 0
}

die() {
        warn "$@. Aborted"
        exit 1
}

rrdcreate() {
        RRD="$1"
        if [ "x${RRD}x" = "xx" ]; then
                die "Missing parameter"
        fi
        touch "$RRD" &>/dev/null || \
                die "Failed to create $RRD"
        rrdtool create "$RRD" --step 60 \
        DS:offset:GAUGE:120:-1:1 \
        DS:jitter:GAUGE:120:0:1 \
        RRA:AVERAGE:0.5:1:1440 \
        RRA:AVERAGE:0.5:10:1008
        return "$?"
}

ntptrack() {
        NTP_SERVER="$1"
        RRD="$2"
        COUNT=9
        while [ $COUNT -ge 0 ]
        do
                #echo "Now running: ntpdate -quv ${NTP_SERVER} 2>/dev/null | awk '{print \$4 \" \" \$6}'"
                #ntpdate -dquv ${NTP_SERVER} #| awk '{print $4 " " $6}'
                OUT="$(/usr/sbin/ntpdate -quv ${NTP_SERVER} 2>/dev/null | /usr/bin/awk '{print $4 " " $6}')"
                if [ "x${OUT}x" != "xx" ]; then
                        break
                fi
                warn "$OUT - Invalid reply. Retrying $COUNT"
                COUNT=$((COUNT - 1))
                sleep 0.5
        done
        if [ $COUNT -le 0 ]; then
                warn "No valid responses received. Skipping"
                return 1
        fi
        OFF=$(echo $OUT | awk '{print $1}')
        JIT=$(echo $OUT | awk '{print $2}')
        echo "Updating $NTP_SERVER with OFFSET: $OFF and JITTER: $JIT"
        rrdtool update "$RRD" "N:$OFF:$JIT" &>/dev/null
        if [ "$?" -ne 0 ]; then
                warn "Failed to update $RRD. Skipping"
                return 1
        fi
        return 0
}

ntpgraph() {
        NTP_SERVER="$1"
        RRD="$2"
        IMG="${3:-${RRD}.png}"
        rrdtool graph "$IMG" \
        --title "NTP Offset & Jitter $NTP_SERVER -- $(date '+%F %T')" \
        --width 1280 --height 1024 \
        --start -24h --end now \
        DEF:offset="${RRD}":offset:AVERAGE \
        DEF:jitter="${RRD}":jitter:AVERAGE \
        LINE2:offset${COLOFF}:"Offset (sec)" \
        LINE2:jitter${COLJIT}:"Jitter (sec)" &>/dev/null
        if [ "$?" -ne 0 ]; then
                warn "Failed to create $IMG"
                return 1
        fi
        return 0
}

case "$1" in
        [Tt][Rr][Aa][Cc][Kk])
                MODE="track"
                shift
                ;;
        [Gg][Rr][Aa][Pp][Hh])
                MODE="graph"
                shift
                ;;
esac

for ip in $@
do
        sn="$(echo $ip | sed 's/\./_/g')"
        rrd="${sn}.rrd"
        img="${sn}.png"
        if [ ! -r "$rrd" ]; then
                rrdcreate "$rrd"
        fi
        if [ ! -r "$rrd" ]; then
                warn "$rrd is not readable! Does it exist? Skipping"
                return 1
        fi
        ntp$MODE "$ip" "$rrd" "$img"
done
