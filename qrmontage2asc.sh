#!/bin/bash

#####
#
# Author: Kevin Douglas <douglk@gmail.com>
#
# Simple command line script to restore ascii armor gpg keys from a QR image.
# You can use the following commands to import your restored keys:
#
#   gpg --import pgp-public-keys.asc
#   gpg --import pgp-private-keys.asc
#
# This script will allow you to convert QR images created with asc2qr.sh
# info an ascii armor pgp key.
#
# This script depends on the following libraries/applications:
#
#   libqrencode (http://fukuchi.org/works/qrencode/)
#   zbar (http://zbar.sourceforge.net)
#
# If you need to backup or restore binary keys, see this link to get started:
#
#   https://gist.github.com/joostrijneveld/59ab61faa21910c8434c#file-gpg2qrcodes-sh
#
#####

# Name of the output key after decoding
output_key_name="mykey.asc"
convert_opts=""
zbarimg_opts=""

# Argument/usage check
if [ $# -ne 2 ]; then
	echo "usage: `basename ${0}` <QR montage image> <image geometry ROWxCOL ex:4x3>"
	exit 1
fi

# Parse the layout
rows=$(echo $2 | cut -d'x' -f1)
cols=$(echo $2 | cut -d'x' -f2)

# Get the image geometry
geometry=$(identify -verbose "${1}" | grep Geometry | sed -e 's/.* \([0-9]\+x[0-9]\+\).*/\1/')
w=$(echo $geometry | cut -d'x' -f1)
h=$(echo $geometry | cut -d'x' -f2)

# For each image on the command line, decode it into text

cw=$(($w/$cols))
ch=$(($h/$rows))

# Calculate blur params
blur_base=1
sigma_base=0.3
chunks=()
tmpfile=$(mktemp --suffix=.png)
for r in $(seq 1 $rows); do
	for c in $(seq 1 $cols); do
		# Create image for this block
		img_id=$((($r-1)*$cols + $c))_$(basename "$1")
		img="$1 : [$r, $c]"
		echo "decoding ${img}"
		# First try without processing
		convert "${1}" -crop ${cw}x${ch}+$(($cw*($c-1)))+$(($ch*($r-1))) -level 80 $convert_opts "${tmpfile}"
		chunk=$( zbarimg --raw --set disable --set qrcode.enable ${zbarimg_opts} "${tmpfile}" 2>/dev/null)

		if [ $? -ne 0 ]; then
			blur_val=$blur_base
			while [ $blur_val -lt 200 ]; do
				sigma_val=$sigma_base
				while [ $(echo "$sigma_val < 1.5" | bc -l) ]; do


					echo "attempting to clean up image with blur $blur_val,$sigma_val ... "
					blur_opts="-despeckle -gaussian-blur $blur_val,$sigma_val -despeckle -level 80 -despeckle"
					sigma_val=$(echo "scale=1; ${sigma_val}+0.1" | bc | sed 's/^\./0\./')
					convert "${1}" -crop ${cw}x${ch}+$(($cw*($c-1)))+$(($ch*($r-1))) $convert_opts $blur_opts "${tmpfile}"
					chunk=$( zbarimg --raw --set disable --set qrcode.enable ${zbarimg_opts} "${tmpfile}" 2>/dev/null) && break
				done

				if [ $? -eq 0 ]; then
					echo "... success"
					break
				fi
				blur_val=$(($blur_val*2))
			done

			if [ $? -ne 0 ]; then
				echo "failed to decode QR image"
				cp "$tmpfile" fail_"$img_id"
				exit 2
			fi
			#cp "$tmpfile" corrected_"$img_id"	
		fi



		#cp "$tmpfile" success_"$img_id"
		chunks+=("${chunk}")
	done
done
rm "$tmpfile"

asc_key=""
for c in "${chunks[@]}"; do
    asc_key+="${c}"
done

echo "creating ${output_key_name}"
echo "${asc_key}" > ${output_key_name}

