#!/bin/sh

# Some error handling just to be safe 
set -e
error_exit() {
    status=$?
    if [ $status -ne 0 ]; then
        echo "❌ An error occurred. Exiting script."
    fi
    exit $status
}
trap 'error_exit' EXIT

# ===== USER INPUT FOR BANNER TEXT =====
echo "Enter your banner text: "
read banner_text

# ===== USER INPUT FOR WEATHER =====
echo "Enter your city name or 3-letter airport code (e.g. New York or JFK):"
read city_input

# Replace spaces with '+'
city_url=$(echo "$city_input" | tr ' ' '+')

# Prompt for units
while true; do
    echo "Do you want the temperature in Fahrenheit or Celsius? (F/C)"
    read unit
    unit=$(echo "$unit" | tr '[:lower:]' '[:upper:]')
    if [ "$unit" = "F" ]; then
        unit_suffix="&u"
        break
    elif [ "$unit" = "C" ]; then
        unit_suffix=""
        break
    else
        echo "Invalid input. Please enter 'F' or 'C'."
    fi
done

# Final weather URL (without the full "curl" yet)
weather_url="wttr.in/${city_url}?format=3${unit_suffix}"

# ===== CONTINUE WITH PACKAGE SETUP =====
ASSUME_ALWAYS_YES=YES pkg install dynamic_motd figlet figlet-fonts curl lolcat 

sysrc update_motd="NO"
sysrc dynamic_motd="YES"
mv /etc/motd.template /etc/motd.template.backup

# ===== WRITE THE DYNAMIC MOTD SCRIPT =====
cat << EOF > /usr/local/etc/rc.motd
#!/bin/sh

# ===== Configuration =====
NAME="$banner_text" #REPLACE WITH YOUR TEXT
FONT_LIST="6x10 graceful larry3d nancyj puffy rectangles basic" #CAN USE ANY FONT AVAILABLE FROM FIGLET
WEATHER_URL="${weather_url}" # Generated dynamically from user input
STATE_FILE="/tmp/motd_font_index"

# ===== Utilities =====
has_cmd() { command -v "\$1" >/dev/null 2>&1; }

colorize() {
    if has_cmd lolcat; then
        lolcat -f
    else
        cat
    fi
}

divider() {
    printf "%s\n" "------------------------------------------------------------"
}

# ===== Font Rotation (POSIX-compliant) =====
set -- \$FONT_LIST  # Turns FONT_LIST into \$1 \$2 \$3 ...
NUM_FONTS=\$#
if [ -f "\$STATE_FILE" ]; then
    INDEX=\$(cat "\$STATE_FILE")
else
    INDEX=0
fi

INDEX=\$((INDEX % NUM_FONTS))
# Rotate font using shift
i=0
for FONT in "\$@"; do
    if [ "\$i" -eq "\$INDEX" ]; then
        break
    fi
    i=\$((i + 1))
done

NEXT_INDEX=\$(( (INDEX + 1) % NUM_FONTS ))
echo "\$NEXT_INDEX" > "\$STATE_FILE"

# ===== Memory Info (FreeBSD) =====
get_mem_info() {
    MEM_TOTAL=\$(sysctl -n hw.physmem)
    MEM_FREE=\$(sysctl -n vm.stats.vm.v_free_count)
    PAGE_SIZE=\$(sysctl -n hw.pagesize)
    MEM_FREE_BYTES=\$((MEM_FREE * PAGE_SIZE))

    TOTAL_MB=\$((MEM_TOTAL / 1024 / 1024))
    FREE_MB=\$((MEM_FREE_BYTES / 1024 / 1024))
    USED_MB=\$((TOTAL_MB - FREE_MB))

    echo "\$USED_MB MiB used / \$TOTAL_MB MiB total"
}

# ===== MOTD Output =====
echo

if has_cmd figlet; then
    figlet -f "\$FONT" "\$NAME" | colorize
else
    echo "\$NAME" | colorize
fi

echo "Font used: \$FONT"
divider | colorize
echo " 🖥️  Hostname : \$(hostname)"
echo " ⏱️  Uptime   : \$(uptime | sed 's/.*up //; s/,.*//' | awk '{\$1=\$1};1')"
echo " 🧠 Memory    : \$(get_mem_info)"

DISK=\$(df -h / | awk 'NR==2 {print \$3 " used / " \$2}')
echo " 💽 Disk      : \$DISK"
echo
divider | colorize
echo
if has_cmd curl; then
    echo
    echo " 🌦️  Weather:"
    curl -s "\$WEATHER_URL" || echo " (unavailable)"
fi

echo
divider | colorize
echo
EOF

chmod +x /usr/local/etc/rc.motd
service dynamic_motd start

# Final success message
echo ""
echo "======================================================"
echo "||           *** Finished installing! ***           ||"
echo "||  Edit the config file at /usr/local/etc/rc.motd  ||"
echo "||       View available fonts at figlet.org         ||"
echo "======================================================"
echo ""

