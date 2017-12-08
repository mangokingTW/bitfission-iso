#!/bin/bash -eu

mkdir -p /srv/tftp/ezio/

echo "#!/bin/sh" > /srv/tftp/ezio/ezio.sh
echo "TFTP=\$(cat /tftp)" >> /srv/tftp/ezio/ezio.sh

tftpfile=$( find /srv/tftp/ezio/ \( -name \*.torrent -o -name \*partition_table \) -print | sort )

partinfo=""
ezioinfo=""
for file in $tftpfile ; do
	rfile=$( echo "$file" | cut -d'/' -f4- )
	lfile=$( echo "$file" | cut -d'/' -f6- )
	echo "busybox tftp -g -l $lfile -r $rfile \$TFTP" >> /srv/tftp/ezio/ezio.sh
	if echo "$lfile" | grep -q partition_table ; then
		disk=$(echo "$lfile" | cut -d'_' -f1)
		partinfo="${partinfo}dd if=$lfile of=/dev/$disk"$'\n'
	fi
	if echo "$lfile" | grep -q torrent ; then
		part=$(echo "$lfile" | cut -d'.' -f1)
		ezioinfo="${ezioinfo}static-ezio $lfile /dev/$part"$'\n'
	fi
done

{ echo "$partinfo"; echo "$ezioinfo"; echo "poweroff -f"; } >> /srv/tftp/ezio/ezio.sh
