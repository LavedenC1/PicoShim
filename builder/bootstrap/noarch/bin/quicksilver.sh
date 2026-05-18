#!/bin/sh
# written mostly by mariah carey (xXMariahScaryXx) 
fail(){
  printf "$1\n"
  printf "please attach error logs and report to crosbreaker on discord or github...\n"
  sleep infinity # so people have time to photograph/record error outputs in reports
}

get_booted_kernnum() {
    if $(expr $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P)); then
        echo -n 2
    else 
        echo -n 4
    fi
}
get_booted_rootnum() {
  expr $(get_booted_kernnum) + 1 
} 
opposite_num() {
    if [ "$1" == "2" ]; then
        echo -n 4 
    elif [ "$1" == "4" ]; then
        echo -n 2
    elif [ "$1" == "3" ]; then
        echo -n 5
    elif [ "$1" == "5" ]; then
        echo -n 3
    else
        return 1
    fi
}

prep_quicksilver() {
	mkdir -p /run/vpd  /localrootA /localrootB
	mount "$intdis$intdis_prefix"3 /localrootA -o ro
	mount "$intdis$intdis_prefix"5 /localrootB -o ro
	
	for root in A B; do
		if [ "$(cat /localroot"$root"/etc/lsb-release | grep MILESTONE | sed 's/^.*=//')" -gt 142 ]; then
    	local root_"$root"_patched=true
		else
			local root_"$root"_patched=false
		fi	
	done
	if [ $root_A_patched == true ] && [ $root_B_patched == true ]; then
  	echo "quicksilver is patched on 143"
  	read -p $'override? (y/N)\n' -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			echo "continuing..."
		else
			fail "please downgrade."
		fi
	elif [ $root_A_patched == true ] && [ $root_B_patched == false ]; then
		cgpt add "$intdis$intdis_prefix" -i 2 -P 0
		cgpt add "$intdis$intdis_prefix" -i 4 -P 1
	elif [ $root_A_patched == false ] && [ $root_B_patched == true ]; then
		cgpt add "$intdis$intdis_prefix" -i 2 -P 1
		cgpt add "$intdis$intdis_prefix" -i 4 -P 0
	fi

	if vpd -i RW_VPD -l | grep re_enrollment > /dev/null 2>&1; then
		quicksilver=true
	else
		quicksilver=false
	fi
	vpd -i RW_VPD -l > /run/vpd/rw.txt
	umount /localroot*
}
do_quicksilver() {
	vpd -i RW_VPD -s "re_enrollment_key"="$(hexdump -e '1/1 "%02x"' -v -n 32 /dev/urandom)" > /dev/null 2>&1
	echo "done! to finish unenrolling, go through oobe in secure mode and FWMP will be cleared."
	sleep 3
}
undo_quicksilver() {
	vpd -i RW_VPD -d re_enrollment_key > /dev/null 2>&1
	echo "done! to re-enroll, go through oobe in secure mode."
	sleep 3
}
get_internal() {
	local ROOTDEV_LIST=$(cgpt find -t rootfs)
	if [ -z "$ROOTDEV_LIST" ]; then
		fail "could not parse for rootdev devices. this should not have happened."
	fi
	local device_type=$(echo "$ROOTDEV_LIST" | grep -oE 'blk0|blk1|nvme|sda' | head -n 1)
	case $device_type in
	"blk0")
		intdis=/dev/mmcblk0
  		intdis_prefix="p"
		break
		;;
	"blk1")
		intdis=/dev/mmcblk1
			intdis_prefix="p"
		break
		;;
	"nvme")
		intdis=/dev/nvme0
  		intdis_prefix="n"
		break
		;;
	"sda")
		intdis=/dev/sda
  		intdis_prefix=""
		break
		;;
	*)
		fail "an unknown error occured. this should not have happened."
		;;
	esac
}

get_internal
prep_quicksilver

if [ $quicksilver = true ]; then
	read -p $'Quicksilver is ENABLED. Would you like to disable it? (y/n)\n' -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		undo_quicksilver
	fi
else
	read -p $'Quicksilver is DISABLED. Would you like to enable it? (y/n)\n' -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		do_quicksilver
	fi
fi
