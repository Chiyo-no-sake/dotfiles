#!/bin/bash

playerctl metadata --format '{{ title }}|||{{ position }}|||{{ mpris:length }}|||{{ xesam:artist }}' 2>/dev/null | awk -F '\\|\\|\\|' '
BEGIN {
    has_meaningful_data = 0;
}

function format_time(total_micros) {
    total_seconds = int(total_micros / 1000000);
    hours = int(total_seconds / 3600);
    minutes = int((total_seconds % 3600) / 60);
    seconds = int(total_seconds % 60);

    if (hours > 0) {
        return sprintf("%02d:%02d:%02d", hours, minutes, seconds);
    } else {
        return sprintf("%02d:%02d", minutes, seconds);
    }
}

{
    title = $1;
    pos_us = $2;
    dur_us = $3;
    author = $4;

    if (title != "" || author != "") {
        has_meaningful_data = 1;

        formatted_pos = format_time(pos_us);
        formatted_dur = format_time(dur_us);

        output_str = "";

        if (author != "") {
            output_str = author;
        }

        if (author != "" && title != "") {
            output_str = output_str " - ";
        }

        if (title != "") {
            output_str = output_str title;
        }

        if (dur_us > 0) {
            output_str = output_str "    " formatted_pos " / " formatted_dur;
        }

        print output_str;
    }
}

END {
    if (has_meaningful_data == 0) {
        print "Nothing playing...";
    }
}
'
