#!/bin/bash

#####
#
# Author: Kevin Douglas <douglk@gmail.com>
#
# Simple command line script to backup ascii armor gpg keys to paper. You can
# use the following commands to export your keys in ascii armor format:
#
#   gpg --armor --export > pgp-public-keys.asc
#   gpg --armor --export-secret-keys > pgp-private-keys.asc
#   gpg --armor --gen-revoke [your key ID] > pgp-revocation.asc
#
# These can then be used to restore your keys if necessary.
#
# This script will allow you to convert the above ascii armor keys into a
# printable QR code for long-term archival.
#
# This script depends on the following libraries/applications:
#
#   libqrencode (http://fukuchi.org/works/qrencode/)
#
# If you need to backup or restore binary keys, see this link to get started:
#
#   https://gist.github.com/joostrijneveld/59ab61faa21910c8434c#file-gpg2qrcodes-sh
#
#####

# Maximum chuck size to send to the QR encoder. QR version 40 supports
# 2,953 bytes of storage.
#max_qr_bytes=2800
qr_bytes_limit=2953

# Split the file into a maxumum number of images
fixed_qr_images=12
qr_dpi=1200
qr_module_size=18 # default 3, 20 is huge
montage_tile=3x4 # COLxROW
montage_filename=QR_montage.png

# Prefix string for the PNG images that are produced
image_prefix="QR"

# Argument/usage check
if [ $# -ne 1 ]; then
	echo "usage: `basename ${0}` <ascii armor key file>"
	exit 1
fi

asc_key=${1}
if [ ! -f "${asc_key}" ]; then
	echo "key file not found: '${asc_key}'"
	exit 1
fi

## Split the key file into usable chunks that the QR encoder can consume
file_length=$(stat -c%s "${asc_key}")
max_qr_bytes=$(( ($file_length + $fixed_qr_images - 1) / $fixed_qr_images ))

# Data density check
if [ "$max_qr_bytes" -gt "$qr_bytes_limit" ]; then
	echo "data density exceeds limit: $max_qr_bytes / QR limt: $qr_bytes_limit"
	exit 1
else
	echo "data density $max_qr_bytes bytes / QR"
fi

chunks=()
while true; do
    IFS= read -r -d'\0' -n ${max_qr_bytes} s
    if [ ${#s} -gt 0 ]; then
        chunks+=("${s}")
    else
        break
    fi
done < ${asc_key}

## For each chunk, encode it into a qr image
index=1
qr_image_list=()
for c in "${chunks[@]}"; do
    img=${image_prefix}$(printf "%0${#fixed_qr_images}d" ${index}).png
    qr_image_list+=($img)
    echo "generating ${img}"
    echo -n "${c}" | qrencode -s $qr_module_size -d $qr_dpi -o ${img}
	if [ $? -ne 0 ]; then
		echo "failed to encode image"
		exit 2
	fi
	index=$((index+1))
done

## Create a montage image marked at the first image
echo "generating $montage_filename"
stroke_width=$(( $qr_module_size / 2 ))
montage ${qr_image_list[*]} -geometry +0+0 -tile $montage_tile - | \
convert - -strokewidth $stroke_width -stroke black \
  -draw "line $stroke_width,$(($stroke_width*50)) $stroke_width,$stroke_width" \
  -draw "line $stroke_width,$(($stroke_width)) $(($stroke_width*50)),$stroke_width" \
  $montage_filename

