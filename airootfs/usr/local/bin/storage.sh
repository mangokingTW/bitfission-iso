#!/usr/bin/bash -eu

storage_type=""
fullpath=""
source "$(dirname $0)/dialog.sh"

select_storage_type(){
	exec 3>&1
	storage_type=$(dialog --no-items --menu "Select the storage type of image"\
		$HEIGHT $WIDTH $BOXHEIGHT \
		"localhost disk" \
		"NFS" \
		"give me a shell" \
		2>&1 1>&3 )
	exec 3>&-
}

mount_local_disk(){
	exec 3>&1
	local_disk=$(dialog --no-items --menu "Select a local disk with the target image"\
		$HEIGHT $WIDTH $BOXHEIGHT \
		$(lsblk -n -l | cut -d' ' -f1) \
		2>&1 1>&3 )
	exec 3>&-

	if [ -n "${local_disk:-}" ] ; then
		mount "/dev/${local_disk}" "/mnt"
	fi
}

localhost_storage(){
	mount_local_disk
	dirbox "Select localhost image path" "/mnt" "fullpath"
	echo $fullpath
}

nfs_storage(){
	mountpath="/mnt"

	inputbox "Type the NFS server IP address or hostname" "nfsip"
	inputbox "Type target path on the NFS server. e.g. \"/srv/nfs/\"" "nfspath"
	mount -t nfs "${nfsip:?}:${nfspath:?}" "${mountpath:?}"
	inputbox "Type the image path e.g. \"image/win10_20170827\"" "imgpath"

	fullpath="${mountpath:?}/${imgpath:?}"
}

select_storage_type

case $storage_type in
	"localhost disk" )
		localhost_storage
		;;
	"NFS" )
		nfs_storage
		;;
	"give me a shell" )
		bash
		localhost_storage
		;;
esac

export fullpath="${fullpath:?}"
