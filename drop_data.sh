#!/bin/sh

# send async data to local collector bin in form of:
# drop_data.sh <DatabinID/name> key value <method> 

# then send data to server:
# drop_data.sh <DatabinID/name> --send 

# method used in case of data collision:
#   max - send only greatest
#   min - send smallest value
#   avg - send average
#   no value: send latest value

WGET=/usr/local/bin/wget

DROPDIR="/tmp/drop_data/$UID"
mkdir $DROPDIR 2> /dev/null

BID_NAME=$1
if [ -z $BID_NAME ]; then
    echo "Missing DatabinID"
    exit 1
fi

if [ -z $2 ]; then
    echo "Missing key"
    exit 1
fi

if [ -f /etc/drop_data.conf ]; then
    BID_ID=`grep -E "^${BID_NAME}\\ " /etc/drop_data.conf | xargs | cut -d' ' -f2`
fi

if [ -z $BID_ID ]; then
    BID=$BID_NAME;
else
    BID=$BID_ID
fi


METHOD=$4
if [ $2 != "--send" ]; then
    KEY=$2
    VAL=$3
    mkdir $DROPDIR/$BID 2>/dev/null
    echo $VAL >> $DROPDIR/$BID/$KEY
    echo $METHOD > $DROPDIR/${KEY}.method
    exit
fi

if $WGET --help | grep -q secure; then
    DDURL="https://datadrop.wolframcloud.com/api/v1.0/Add?bin=$BID"
else
    DDURL="http://datadrop.wolframcloud.com/api/v1.0/Add?bin=$BID"
fi

if ! [ -d $DROPDIR/$BID ]; then
    echo "No data!"
    exit 1
fi

for key in `ls -1 $DROPDIR/$BID/`; do
    METHOD=`cat $DROPDIR/${key}.method`
    case "$METHOD" in
        min)
            data=`sort -n $DROPDIR/$BID/$key | head -n 1`
            ;;
        max)
            data=`sort -nr $DROPDIR/$BID/$key | head -n 1`
            ;; 
        avg)
            data=`awk '{sum+=sprintf("%d",$1)}END{printf "%d\n",sum/NR}' $DROPDIR/$BID/$key`
            ;;
        avgf)
            data=`awk '{sum+=sprintf("%f",$1)}END{printf "%.6f\n",sum/NR}' $DROPDIR/$BID/$key`
            ;;
        \?)
            echo "no such method: $METHOD"
            data=`tail -n 1 $DROPDIR/$BID/$key`
            ;;
        "")
            data=`tail -n 1 $DROPDIR/$BID/$key`
            ;;
        *)
            echo "UNKNOWN: $METHOD"
            data=`tail -n 1 $DROPDIR/$BID/$key`
            ;;
    esac
    DDURL="${DDURL}&${key}=${data}"
done

echo "Dropping data with $DDURL"
rm -rf $DROPDIR/$BID
$WGET -T 30 -t 5 "$DDURL" -q -O -
