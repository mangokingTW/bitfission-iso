#!/usr/bin/bash -eu

export WIDTH=60
export HEIGHT=30
export BOXHEIGHT=30
export DIALOG_OK=0
export DIALOG_CANCEL=1
export DIALOG_HELP=2
export DIALOG_EXTRA=3
export DIALOG_ITEM_HELP=4
export DIALOG_ESC=255

inputbox(){
	# inputdialog text return_variable
	exec 3>&1
	export declare $2=$(dialog --inputbox "$1"\
		$HEIGHT $WIDTH \
		2>&1 1>&3 )
	exec 3>&-
}

msgbox(){
	dialog --msgbox "$1" $HEIGHT $WIDTH
}

dirbox(){
	cwd="$2"

	while true ; do
		status=$DIALOG_OK
		exec 3>&1
		dir=$(dialog --no-items \
			--extra-button --extra-label "Change Directory" \
   			--menu "${1}: $cwd" \
			$HEIGHT $WIDTH $BOXHEIGHT \
			$(ls -a "$cwd") \
			2>&1 1>&3 ) || status=$?
		exec 3>&-

		case "$status" in
			$DIALOG_OK )
				if [ -d "${cwd}/${dir}" ] ; then
					cwd="$(realpath "${cwd}/${dir}")"
					export declare "$3"="$cwd"
					echo $cwd
					return 0
				else
					msgbox "$cwd/${dir} is a regular file."
				fi
				;;
			$DIALOG_CANCEL )
				exit 1
				;;
			$DIALOG_EXTRA )
				if [ -d "${cwd}/${dir}" ] ; then
					cwd="$(realpath "${cwd}/${dir}")"
				fi
				;;
			$DIALOG_ESC )
				exit 1
				;;
		esac
	done
}

export -f inputbox
export -f msgbox
export -f dirbox
