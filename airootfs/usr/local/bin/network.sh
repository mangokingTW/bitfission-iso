#!/usr/bin/sh -eu

NIC=""
ipaddr=""
netmask=""
broadcast=""
gateway=""

select_nic(){
	exec 3>&1
	NIC=$(dialog --no-items --menu "Network Interface Card"\
		$HEIGHT $WIDTH $BOXHEIGHT \
		$(ls /sys/class/net) \
		2>&1 1>&3 )
	exec 3>&-

	status=$?

	case $status in
		$DIALOG_CANCEL)
			exit 1
			;;
		$DIALOG_ESC)
			exit 1
			;;
	esac
}

static_ip(){
	exec 3>&1
	OPT=$(dialog --form "Static IP Configuration" \
		$HEIGHT $WIDTH $BOXHEIGHT \
		"IPv4 address" 1 1 "10.3.24.1"   1 15 15 0 \
		"Network Mask" 2 1 "24"          2 15 15 0 \
		"Broadcast"    3 1 "10.3.24.255" 3 15 15 0 \
		"Gateway"      4 1 "10.3.24.254" 4 15 15 0 \
		2>&1 1>&3 )
	exec 3>&-
	ipaddr=$( sed -n 1p <<< ${OPT} )
	netmask=$( sed -n 2p <<< ${OPT} )
	broadcast=$( sed -n 3p <<< ${OPT} )
	gateway=$( sed -n 4p <<< ${OPT} )
	ip link set "${NIC}" down
	ip addr flush dev "${NIC}"
	ip link set "${NIC}" up
	ip addr add "${ipaddr}"/"${netmask}" broadcast "${broadcast}" dev "${NIC}"
	ip route add default via "${gateway}"
}

dhcp_server(){
	dialog --yesno "Start DHCP server?" $HEIGHT $WIDTH || return 0
	inputbox "DHCP ip begin e.g. 10.3.24.10" "begin"

	inputbox "DHCP ip end e.g. 10.3.24.250" "end"

	sed -i.bak s/_BEGIN_/"${begin}"/g /etc/dnsmasq.conf
	sed -i.bak s/_END_/"${end}"/g /etc/dnsmasq.conf
	sed -i.bak s/_GATEWAY_/"${gateway}"/g /etc/dnsmasq.conf
	sed -i.bak s/\#//g /etc/dnsmasq.conf
}

exec 3>&1
TYPE=$(dialog --menu "Network Configuration"\
	$HEIGHT $WIDTH $BOXHEIGHT \
	1 "DHCP" \
	2 "STATIC IP" \
	2>&1 1>&3 )
exec 3>&-

status=$?

case $status in
	$DIALOG_CANCEL)
		exit 1
		;;
	$DIALOG_ESC)
		exit 1
		;;
esac

select_nic
sed -i.bak s/_NIC_/"${NIC}"/g /etc/dnsmasq.conf

case $TYPE in
	1 )
		systemctl start dhcpcd@${NIC}
		ipaddr="$(ip route get 1 | awk '{print $7;exit}')"
		;;
	2 )
		static_ip
		dhcp_server
		;;
esac

sed -i.bak s/_HTTP_/"${ipaddr}"/g /srv/tftp/grub/boot/grub/grub.cfg
grub-mkstandalone -d /usr/lib/grub/x86_64-efi/ -O x86_64-efi --fonts="unicode" -o /srv/tftp/grub/bootx64.efi /srv/tftp/grub/boot/grub/grub.cfg

systemctl start dnsmasq
systemctl start darkhttpd

export ipaddr=${ipaddr}
