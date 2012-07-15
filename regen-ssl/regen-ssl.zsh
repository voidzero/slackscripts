#!/bin/zsh

local log="/var/log/regencerts.log"
local from="artemis@caffeine-powered.net"
local to="root"
local maxlogs=3
float maxsize=1.5 # Megabytes

########
########
########
# We need these
zmodload zsh/{stat,mathfunc}

local runtime=${(%)$(echo %D{%Y%m%d%H:%M%S})}
integer logfd i logint
float logsize=$(stat +size ${log})
local logunit=b


[[ -f ${log} ]] || touch ${log} || { echo "Error: $0 is unable to touch $log. Bailing." >&2; exit 1 }

# See if logsize is bigger than 3M, if yes then delete the third
# backup, rotate the logs, start in a new log, and create a logentry
# there.

if (( logsize / 1024000 > maxsize )); then
    # Check if there is a logfile that has to be deleted because it
    # would be $maxlogs + 1, if yes then email it, delete it, and
    # rotate the other logfiles.

    if [[ -e ${log}.${maxlogs}.xz ]]
    then
        cat | from=$from mail -s "$(hostname): regencerts logfile backup" \
                   -a ${log}.${maxlogs}.xz $to <<EOF
Hi. This email is to inform you that the file $log.3.xz on $(hostname)
has been removed due to size and maximum backup restrictions. You may find
a backup of this file attached in this email. It crossed the maximum
filesize of 1.5M.

Sincerely yours,
$(hostname) admin via cron script $0.

EOF

        shred -zu ${log}.${maxlogs}.xz
    fi

    # Rotate
    for ((i=${maxlogs}; i>= 1; --i))
    do
        local _mvlog="${log}.$((i-1)).xz"
        local _tolog="${log}.${i}.xz"
        [[ -f $_mvlog ]] && mv $_mvlog $_tolog
    done
    mv ${log} ${log}.1
    xz -9e ${log.1}
    local rotated=${(%)$(echo %D{%Y%m%d%H:%M%S})}
fi

if (( $logsize > 1024 ))
then
    ((logsize = logsize/1024))
    logunit=K
    if (( logsize > 1024 ))
    then
        ((logsize = logsize/1024))
        logunit=M
    fi
fi

(( logint = rint(logsize) ))

exec {logfd}>>$log 1>&$logfd 2>&$logfd

echo "---\nHi. Regencerts was started from $PWD on $runtime."
[[ -n $rotated ]] && echo "Warning: the logfile was rotated on $rotated. This is a new logfile."
[[ -z $rotated ]] && echo "Current logsize: ${logint}${logunit}."
echo "---\nBeginning operation.\n"

set -G
echo 'cp -uv /etc/ssl/{my,}certs/*{pem,crt}(:A) /etc/postfix/ssl/*{crt,pem}(:A) /var/spool/postfix/ssl'
cp -uv /etc/ssl/{my,}certs/*{pem,crt}(:A) /var/spool/postfix/ssl
set +G

echo '*.crt -> *.pem'

for crt in /var/spool/postfix/ssl/*crt
do
    [[ -L ${crt:r}.pem ]] || ln -s $crt ${crt:r}.pem
done

echo
/usr/bin/c_rehash
echo
/usr/bin/c_rehash /etc/ssl/mycerts
echo
/usr/bin/c_rehash /var/spool/postfix/ssl
echo

echo "---\nRegencerts finished on ${(%)$(echo %D{%Y%m%d%H:%M%S})}.\n---\n" >&$logfd

exec {logfd}>&-

# vim: ts=4 sw=4 et tw=70

