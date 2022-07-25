#!/bin/bash

PGPI_NAME="$(basename $(readlink -f "$BASH_SOURCE") )"
PGPI_VERSION="0.0.1"

### Constants ###

### Default option values ###

NUM_COPIES=1

### Handling options ###

helpmsg="Usage: $PGPI_NAME [-n NUM_COPIES] UID_or_PUBKEY

Options:
    -n, --num NUM_COPIES   number of copies (default: $NUM_COPIES)
    -k, --key PUBKEY   PUBKEY (to avoid lookup)
"

for ((i=0;$#;)) ; do
case "$1" in
	-n|--num) shift ; NUM_COPIES="$1" ;;
	-k|--key) shift
		if [[ ${#1} != 44 ]] ; then
			echo "Warning: key $1 don't contain 44 chars -> ignored" >&2
		else
			p="$1"
		fi
		;;
	-h|--h*) echo "$helpmsg" ; exit ;;
	-V|--vers*) echo "$PGPI_NAME $PGPI_VERSION" ; exit ;;
	--) shift ; break ;;
	-*) echo -e "Error: Unrecognized option $1\n$helpmsg" >&2 ; exit 2 ;;
	*) break ;;
esac
shift
done
UIDP="$1"


### functions ###

. "$(dirname "$BASH_SOURCE")"/bl-interactive --frontend whiptail --

### Init ###

### Run ###

set -e
set -o pipefail


if [[ -z $p ]] ; then
	echo "Looking for $UIDP ..."
	lookup="$(silkaj lookup "$UIDP" )"
	echo "$lookup"
	lookup="$(grep "^→" <<<"$lookup")"
	mapfile -t keys <<<"$lookup"

	choosed=$(bl_radiolist --output-value --num-per-line 1 --default 1 --text "Which keys to print ?" "${keys[@]}")
	IFS=" :" read f p k f uid etc <<<"$choosed"
else
	uid="$UIDP"
fi

echo -n "$p" | qrencode --level=M --output tmp.png

cat <<EOF | pandoc --from markdown --to pdf -fmarkdown-implicit_figures | pdfcrop --margins "4" - "tmp.pdf"
\pagenumbering{gobble}

## Ğ1 - ${uid::24}

![qrcode](tmp.png)

*${p::10}...${p:36}*
EOF

if ((NUM_COPIES)) ; then
	printers=($(LANG= lpstat -p | sed -n 's,^printer \([^ ]*\).*,\1,p')) || { echo "Error: No printer detected" >&2 ; exit 1 ; }
	printer="$(bl_radiolist --output-value --default-value "$(lpstat -d | sed 's,.* ,,')" --num-per-line 1 --text "Where to print ?" "${printers[@]}")"
	lpstat -p "${printer}"
	lpr -# "$NUM_COPIES" -P "$printer" "tmp.pdf"
fi

exit

