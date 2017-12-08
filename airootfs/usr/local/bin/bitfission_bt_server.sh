#!/usr/bin/bash -eu
echo "Select NIC for dhcpd and tftpd: "
ls /sys/class/net/
read NIC

echo "Static IP address e.g. 10.3.24.1: "
read ipaddr

echo "Netmask e.g. 24: "
read netmask

echo "MTU size e.g. 1500: "
read mtu

echo "broadcast e.g. 10.3.24.255: "
read broadcast

echo "Default gateway e.g. 10.3.24.254: "
read gateway

ip link set ${NIC} mtu ${mtu}
ip link set ${NIC} up
ip addr add ${ipaddr}/${netmask} broadcast ${broadcast} dev ${NIC}
ip route add default via ${gateway}

echo "DHCP ip begin e.g. 10.3.24.10:"
read begin

echo "DHCP ip end e.g. 10.3.24.250:"
read end

sed -i.bak s/_NIC_/${NIC}/g /etc/dnsmasq.conf
sed -i.bak s/_BEGIN_/${begin}/g /etc/dnsmasq.conf
sed -i.bak s/_END_/${end}/g /etc/dnsmasq.conf
sed -i.bak s/_GATEWAY_/${gateway}/g /etc/dnsmasq.conf
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
		transmission-edit -a "http://${ipaddr}:6969/announce" /srv/tftp/ezio/${disk}/${part}.torrent
		mount -t squashfs /mnt/${imgpath}/${disk}/${part}.img /tmp/bitfission/${disk}/${part}/
		offset="$( partclone.info /tmp/bitfission/${disk}/${part}/image.img 2>/dev/null | cut -d ' ' -f4 )"
		if [[ -z "${offset}" ]] ; then offset="0" ; fi
		echo "${offset} /tmp/bitfission/${disk}/${part}/image.img /srv/tftp/ezio/${disk}/${part}.torrent" >> torrent.list
	done

	echo "Do you want to clone another disk? (y/N)"
	read yorn
	if [ "${yorn}" != "y" ] && [ "${yorn}" != "Y" ] ; then
		break
	fi
done

create_ezio_config.sh
chmod a+r -R /srv/tftp/ezio/
killall -p opentracker || echo "No existing tracker service, starting..."
opentracker &
bt_server -l torrent.list
