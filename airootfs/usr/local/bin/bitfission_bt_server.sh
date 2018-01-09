#!/usr/bin/bash -eu
echo "Select NIC for dhcpd and tftpd: "
ls /sys/class/net/
read -r NIC

echo "Static IP address e.g. 10.3.24.1: "
read -r ipaddr

echo "Netmask e.g. 24: "
read -r netmask

echo "broadcast e.g. 10.3.24.255: "
read -r broadcast

echo "Default gateway e.g. 10.3.24.254: "
read -r gateway

sed -i.bak s/_NIC_/"${NIC}"/g /etc/dnsmasq.conf

echo "Run DHCP server? (y/N)"
read -r yorn

if [ "${yorn}" = "y" ] || [ "${yorn}" = "Y" ]
then
	echo "DHCP ip begin e.g. 10.3.24.10:"
	read -r begin

	echo "DHCP ip end e.g. 10.3.24.250:"
	read -r end

	sed -i.bak s/_BEGIN_/"${begin}"/g /etc/dnsmasq.conf
	sed -i.bak s/_END_/"${end}"/g /etc/dnsmasq.conf
	sed -i.bak s/_GATEWAY_/"${gateway}"/g /etc/dnsmasq.conf
	sed -i.bak s/\#//g /etc/dnsmasq.conf
fi

ip link set "${NIC}" up
ip addr add "${ipaddr}"/"${netmask}" broadcast "${broadcast}" dev "${NIC}"
ip route add default via "${gateway}"

sed -i.bak s/_HTTP_/"${ipaddr}"/g /srv/tftp/grub/boot/grub/grub.cfg
grub-mkstandalone -d /usr/lib/grub/x86_64-efi/ -O x86_64-efi --fonts="unicode" -o /srv/tftp/grub/bootx64.efi /srv/tftp/grub/boot/grub/grub.cfg

systemctl start dnsmasq
systemctl start darkhttpd

echo "Type the NFS server IP address or hostname: "
read -r nfsip
echo "Type target path on the NFS server: "
read -r nfspath
mount -t nfs "${nfsip}":"${nfspath}" /mnt

echo "Type the image path e.g. image/win10_20170827 : "
read -r imgpath

echo -n "" > torrent.list

while true ; do
	echo "Type target disk e.g. sda : "
	read -r disk
	mkdir -p /tmp/bitfission/"${disk}"
	mkdir -p /srv/tftp/ezio/"${disk}"
	cp /mnt/"${imgpath}"/"${disk}"/partition_table /srv/tftp/ezio/"${disk}"/"${disk}"_partition_table
	
	partitions=$( find /mnt/"${imgpath}"/"${disk}"/ -name "*.img" | sed -e 's/.*\/\(.*\)\.img/\1/' )
	for part in ${partitions}; do
		mkdir -p /tmp/bitfission/"${disk}"/"${part}"/
		cp /mnt/"${imgpath}"/"${disk}"/"${part}".torrent /srv/tftp/ezio/"${disk}"/"${part}".torrent
		transmission-edit -a "http://""${ipaddr}"":6969/announce" /srv/tftp/ezio/"${disk}"/"${part}".torrent
		mount -t squashfs /mnt/"${imgpath}"/"${disk}"/"${part}".img /tmp/bitfission/"${disk}"/"${part}"/
		offset=$( /usr/local/bin/partclone.info /tmp/bitfission/"${disk}"/"${part}"/image.img 2>/dev/null | cut -d ' ' -f4 )
		if [[ -z "${offset}" ]] ; then offset="0" ; fi
		echo "${offset} /tmp/bitfission/${disk}/${part}/image.img /srv/tftp/ezio/${disk}/${part}.torrent" >> torrent.list
	done

	echo "Do you want to clone another disk? (y/N)"
	read -r yorn
	if [ "${yorn}" != "y" ] && [ "${yorn}" != "Y" ] ; then
		break
	fi
done

create_ezio_config.sh
chmod a+r -R /srv/tftp/ezio/
killall -p opentracker || echo "No existing tracker service, starting..."
opentracker &
bt_server -l torrent.list
