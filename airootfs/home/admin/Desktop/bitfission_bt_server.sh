#!/usr/bin/bash -eu
echo "Select NIC for dhcpd and tftpd"
ls /sys/class/net/
read NIC
sed -i.bak s/_NIC_/${NIS}/g /etc/dnsmasq.conf
systemctl start dnsmasq

echo "Type the NFS server IP address or hostname: "
read nfsip
echo "Type target path on the NFS server: "
read nfspath
mount -t nfs ${nfsip}:${nfspath} /mnt

echo "Type the image path e.g. image/win10_20170827 : "
read imgpath

echo -n "" > torrent.list

while [ 1 ] ; do
	echo "Type target disk e.g. sda : "
	read disk
	mkdir -p /tmp/bitfission/${disk}
	mkdir -p /srv/tftp/ezio/${disk}
	cp /mnt/${imgpath}/${disk}/partition_table /srv/tftp/ezio/${disk}/${disk}_partition_table
	
	partitions=$( ls /mnt/${imgpath}/${disk}/ | grep ".*\.img" | cut -d'.' -f1 )
	for part in ${partitions}; do
		mkdir -p /tmp/bitfission/${disk}/${part}/
		cp /mnt/${imgpath}/${disk}/${part}.torrent /srv/tftp/ezio/${disk}/${part}.torrent
		mount -t squashfs /mnt/${imgpath}/${disk}/${part}.img /tmp/bitfission/${disk}/${part}/
		offset="$( partclone.info /tmp/bitfission/${disk}/${part}/image.img 2>/dev/null | cut -d ' ' -f4 )"
		if [[ -z "${offset}" ]] ; then offset="0" ; fi
		echo "${offset} /tmp/bitfission/${disk}/${part}/image.img /mnt/${imgpath}/${disk}/${part}.torrent" >> torrent.list
	done

	echo "Do you want to clone another disk? (y/N)"
	read yorn
	if [ "${yorn}" != "y" ] && [ "${yorn}" != "Y" ] ; then
		break
	fi
done

./create_ezio_config.sh

bt_server -l torrent.list
