#!/bin/sh

# Use. Available variables:
# "oldness" variable. Defines which image to retrieve. 
# - "0" (default) or "1" means latest already available.
# - greater than "0" specifies the oldness, so "3" means the third oldest image. Only looks into the current hour folder. So if value is greater than the iamges in the latest hour folder, the last one will be sent.
# - negative value (e.g. "-1") means to wait for the next available image. Only works if an image is already being recorded, max. time to wait 80 seconds.
# "type" variable. Defines what to retrieve.
# - "1" (default). Gets relative name in the format of DIR/VIDEO.jpg
# - "2". Gets full URL image.
# - "3". Gets the video itself as video/jpg.
# Examples of use:
# http://IP:PORT/cgi-bin/getlastrecordedsnapshot.sh?oldness=-1&type=3 -- Wait for a new image and shows it in the browser.
# http://IP:PORT/cgi-bin/getlastrecordedsnapshot.sh?type=1            -- Send the relative route of the last available image.
# http://IP:PORT/cgi-bin/getlastrecordedsnapshot.sh?oldness=2&type=2  -- Send the URL of the second to last available image.

YI_HACK_PREFIX="/home/yi-hack"

. $YI_HACK_PREFIX/www/cgi-bin/validate.sh

if ! $(validateQueryString $QUERY_STRING); then
    printf "Content-type: application/json\r\n\r\n"
    printf "{\n"
    printf "\"%s\":\"%s\"\\n" "error" "true"
    printf "}"
    exit
fi

CONF_LAST="CONF_LAST"
OLDNESS=0
TYPE=1

for I in 1 2
do
    CONF="$(echo $QUERY_STRING | cut -d'&' -f$I | cut -d'=' -f1)"
    VAL="$(echo $QUERY_STRING | cut -d'&' -f$I | cut -d'=' -f2)"

    if [ $CONF == $CONF_LAST ]; then
        continue
    fi
    CONF_LAST=$CONF

    if [ "$CONF" == "oldness" ] ; then
        OLDNESS=$VAL
    elif [ "$CONF" == "type" ] ; then
        TYPE=$VAL
    fi
done



if [ "$OLDNESS" -lt "0" ]; then

    # This section just wait until a new file comes or we timeout. After that, the next section will give the last modified file.
    # If oldness is negative, try to wait until a new file comes.
    if [ -f "/tmp/sd/record/tmp.mp4.tmp" ]; then
        # A file is being recorded, therefore, try to get it when it finished saving.
        # First, we get the last directory.
        for f in `ls -Ar /tmp/sd/record | grep H`; do
            if [ ${#f} == 14 ]; then
                DIRNAME="$f"
                break;
            fi
        done

        # Now we get the number of directories and files in the last modified directory.
        FILECOUNT=`ls -Ar /tmp/sd/record/$DIRNAME | grep .jpg -c`
        DIRCOUNT=`ls -Ar /tmp/sd/record/ | grep H -c`
        SLEEPCOUNT=0
        while [ "$FILECOUNT" -eq `ls -Ar /tmp/sd/record/$DIRNAME | grep .jpg -c` ]; do
            if [ "$SLEEPCOUNT" -gt 800 ]; then
                # After 80 seconds, we break the wait.
                break;
            elif [ "$DIRCOUNT" -lt `ls -Ar /tmp/sd/record/ | grep H -c` ]; then
                # If a new dir comes, we break the wait.
                break;
            fi
            sleep 0.1
            SLEEPCOUNT=$(($SLEEPCOUNT+1))
        done
    fi
fi


for f in `ls -Ar /tmp/sd/record | grep H`; do
    if [ ${#f} == 14 ]; then
        DIRNAME="$f"
        break;
    fi
done
# In $DIRNAME we now has the last modified directory.

COUNT=`ls -Ar /tmp/sd/record/$DIRNAME | grep .jpg -c`
IDX=1
for f in `ls -Ar /tmp/sd/record/$DIRNAME | grep .jpg`; do
    if [ ${#f} == 12 ] || [ ${#f} == 14 ]; then
        IMGNAME="$f"
        if [ "$IDX" -ge "$OLDNESS" ]; then
            break;
        elif [ "$IDX" == "$COUNT" ]; then
            break;
        fi
        IDX=$(($IDX+1))
    fi
done

if [ "$TYPE" == "2" ]; then
    LOCAL_IP=$(ifconfig wlan0 | awk '/inet addr/{print substr($2,6)}')
    source /home/yi-hack/etc/system.conf

    printf "Content-type: text/plain\r\n\r\n"
    echo "http://$LOCAL_IP:$HTTPD_PORT/record/$DIRNAME/$IMGNAME"
elif [ "$TYPE" == "3" ]; then
    printf "Content-type: image/jpeg; charset=utf-8\r\nContent-Disposition: inline; filename=\"$IMGNAME\"\r\n\r\n"
    cat /tmp/sd/record/$DIRNAME/$IMGNAME
    exit
elif [ "$TYPE" == "4" ]; then
    printf "Content-type: image/jpeg; charset=utf-8\r\nContent-Disposition: attachment; filename=\"$IMGNAME\"\r\n\r\n"
    cat /tmp/sd/record/$DIRNAME/$IMGNAME
    exit
else
    # Default and type=1
    printf "Content-type: text/plain\r\n\r\n"
    echo "$DIRNAME/$IMGNAME"
    exit
fi
