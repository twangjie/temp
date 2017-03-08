#/bin/bash

yesterday=`date -d -1day +%Y%m%d`

table=tip_image_$yesterday

echo "enable '$table'" > /tmp/major_compact.cmd
echo "major_compact '$table'" >> /tmp/major_compact.cmd
echo "exit" >> /tmp/major_compact.cmd

