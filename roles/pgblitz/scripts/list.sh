#!/bin/bash
#
# [Ansible Role]
#
# GitHub:   https://github.com/Admin9705/PlexGuide.com-The-Awesome-Plex-Server
# Author:   Admin9705 & FlickerRate
# URL:      https://plexguide.com
#
# PlexGuide Copyright (C) 2018 PlexGuide.com
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
#################################################################################
echo "INFO - PGBlitz: Starting JSON Building Process" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
path=/opt/appdata/pgblitz/keys
number=0

### NOTES
# 1. Build JSON Checkers for Quality Control to ensure valid
# 2. If file is not a JSON, trash it
# 3. Ensure that no more than 99 JSON's can be built - 100 limiter
# 4. Testing for now, but have invalid JSONs go to an invalid folder


ls -la $path/unprocessed | awk '{ print $9}' | tail -n +4 > /tmp/pg.keys.temp
ls -la $path/processed | awk '{ print $9}' | tail -n +4 > /tmp/pg.keys.unprocessed.count

rm -r $path/unprocessed/* 1>/dev/null 2>&1
rm -r $path/processed/* 1>/dev/null 2>&1
rm -r $path/.originalnames/* 1>/dev/null 2>&1

rm -r /tmp/pg.keys.processed.count 1>/dev/null 2>&1
while read p; do
  p=${p:4}
  echo $p >> /tmp/pg.keys.processed.count
done </tmp/pg.keys.unprocessed.count

while read p; do
  let "number++"
  until [ "$break" == "1" ]; do
    check=$(grep -w "$number" /tmp/pg.keys.processed.count)
    if [ "$check" == "$number" ]; then
        break=0
        let "number++"
        echo "INFO - PGBlitz: GDSA$number Exists - Skipping" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
      else
        break=1
    fi
  done

  mv $path/unprocessed/$p $path/processed/GDSA$number
  echo "$path/unprocessed/.$p" > "$path/.originalnames/GDSA$number"
  echo "INFO - PGBlitz: GDSA$number Established" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
done </tmp/pg.keys.temp

echo "INFO - PGBlitz: JSON Building Process List Complete" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
