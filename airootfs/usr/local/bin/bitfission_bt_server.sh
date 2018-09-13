#!/usr/bin/bash -eu

scriptpath="$(dirname "$0")"

# shellcheck source=/usr/local/bin/dialog.sh
source "${scriptpath}/dialog.sh"

# shellcheck source=/usr/local/bin/network.sh
source "${scriptpath}/network.sh"

if [ -z "${ipaddr-}" ] ; then
	msgbox "Could not get an IP address."
	exit 1
fi

# shellcheck source=/usr/local/bin/storage.sh
source "${scriptpath}/storage.sh"

if [ -z "${fullpath-}" ] ; then
	msgbox "Could not get the image path."
	exit 1
fi

echo -n "" > torrent.list

while true ; do
	inputbox "Type target disk e.g. sda" "disk"
	if [ -z "${disk-}" ] ; then
		msgbox "Unknown target disk."
		exit 1
	fi
	mkdir -p /tmp/bitfission/"${disk}"
	mkdir -p /srv/tftp/ezio/"${disk}"
	cp "${fullpath}"/"${disk}"/partition_table.dd /srv/tftp/ezio/"${disk}"/"${disk}"_partition_table.dd || \
	cp "${fullpath}"/"${disk}"/partition_table.sgdisk /srv/tftp/ezio/"${disk}"/"${disk}"_partition_table.sgdisk

	partitions=$( find "${fullpath}"/"${disk}"/ -name "*.img" | sed -e 's/.*\/\(.*\)\.img/\1/' )
	for part in ${partitions}; do
		mkdir -p /tmp/bitfission/"${disk}"/"${part}"/
		cp "${fullpath}"/"${disk}"/"${part}".torrent /srv/tftp/ezio/"${disk}"/"${part}".torrent
		transmission-edit -a "http://""${ipaddr}"":6969/announce" /srv/tftp/ezio/"${disk}"/"${part}".torrent &>/dev/null
		mount -t squashfs "${fullpath}"/"${disk}"/"${part}".img /tmp/bitfission/"${disk}"/"${part}"/
		offset=$( /usr/local/bin/partclone.info /tmp/bitfission/"${disk}"/"${part}"/image.img 2>/dev/null | cut -d ' ' -f4 )
		if [[ -z "${offset}" ]] ; then offset="0" ; fi
		echo "${offset} /tmp/bitfission/${disk}/${part}/image.img /srv/tftp/ezio/${disk}/${part}.torrent" >> torrent.list
	done

	dialog --yesno "Do you want to clone another disk? (y/N)" 0 0 || break
done

create_ezio_config.sh
chmod a+r -R /srv/tftp/ezio/
killall -p opentracker &>/dev/null || true
opentracker &
bt_server -a 3 -c 3 -u 3 -l torrent.list
