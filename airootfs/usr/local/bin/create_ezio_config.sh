#!/bin/bash -eu

mkdir -p /srv/tftp/ezio/

echo "#!/bin/sh" > /srv/tftp/ezio/ezio.sh
echo "TFTP=\$(cat /tftp)" >> /srv/tftp/ezio/ezio.sh

tftpfile=$( find /srv/tftp/ezio/ \( -name \*.torrent -o -name \*partition_table \) -print | sort )

partinfo=""
ezioinfo=""
for file in $tftpfile ; do
	rfile=$( echo $file | cut -d'/' -f4- )
	lfile=$( echo $file | cut -d'/' -f6- )
	echo "busybox tftp -g -l $lfile -r $rfile \$TFTP" >> /srv/tftp/ezio/ezio.sh
	if [ -n "$(echo $lfile | grep partition_table)" ] ; then
		disk=$(echo $lfile | cut -d'_' -f1)
		partinfo="${partinfo}dd if=$lfile of=/dev/$disk"$'\n'
	fi
	if [ -n "$(echo $lfile | grep torrent)" ] ; then
		part=$(echo $lfile | cut -d'.' -f1)
		ezioinfo="${ezioinfo}static-ezio $lfile /dev/$part"$'\n'
	fi
done

echo "$partinfo" >> /srv/tftp/ezio/ezio.sh
echo "$ezioinfo" >> /srv/tftp/ezio/ezio.sh

echo "poweroff" >> /srv/tftp/ezio/ezio.sh
