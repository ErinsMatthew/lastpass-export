#!/bin/bash

usage() {
    cat << EOT 1>&2
Usage: export.sh [-h] [-d] [-f] [-c opt] [-s] -u username dir

OPTIONS
=======
-c opt       color option: one of: auto, never, or always
-d           output debug information
-f           overwrite output file if it already exists
-h           show help
-s           stay logged in after script finishes
-u username  login to LastPass using username

ARGUMENTS
=========
dir          number of one or more videos to look for

EXAMPLES
========
# export LastPass items for myusername to /tmp/lpass
$ export.sh -d -f -s -u myusername /tmp/lpass

EOT

    exit
}

[[ $# -eq 0 ]] && usage

debug() {
    if [[ ${DEBUG} == 'true' ]]; then
        echo $*
    fi
}

while getopts ":hc:dfsu:" FLAG; do
    case "${FLAG}" in
        d)
            DEBUG='true'

            debug "Debug mode turned on."
            ;;

        c)
            if [[ ${OPTARG} == 'auto' ]] || [[ ${OPTARG} == 'never' ]] || [[ ${OPTARG} == 'always' ]]; then
                COLOR_OPTION="--color=${OPTARG}"
            fi
            ;;

        f)
            OVERWRITE_OPTION='-f'

            debug "Force overwrite mode turned on."
            ;;

        s)
            STAY_LOGGED_IN='true'

            debug "Stay logged in mode turned on."
            ;;

        u)
            USERNAME=${OPTARG}

            debug "Username set to '${USERNAME}'."
            ;;

        h | *)
            usage
            ;;
    esac
done

shift $(( OPTIND - 1 ))

[[ $# -eq 0 ]] && usage

OUTPUT_DIR=$1

if [[ -z ${USERNAME} ]] || [[ -z ${OUTPUT_DIR} ]]; then
    debug "Missing username and/or output directory."

    usage
fi

setDefaults() {
    if [[ -z ${COLOR_OPTION} ]]; then
        COLOR_OPTION='--color=never'

        debug "Color option set to default of '${COLOR_OPTION}'."
    fi

    if [[ -z ${OVERWRITE_OPTION} ]]; then
        OVERWRITE_OPTION=''

        debug "Overwrite option set to default of '${OVERWRITE_OPTION}'."
    fi
}

setDefaults

dependencyCheck() {
    for d in cat cut file grep lpass realpath sed; do
        debug "Checking for dependency '${d}'."

        if ! command -v ${d} &> /dev/null; then
            echo "Dependency '${d}' is missing." > /dev/stderr

            exit
        fi
    done
}

dependencyCheck

login() {
    debug "Logging into LastPass as '${USERNAME}'."

    #lpass login ${OVERWRITE_OPTION} ${COLOR_OPTION} $USERNAME
}

logout() {
    if [[ ${STAY_LOGGED_IN} == 'true' ]]; then
        debug "Staying logged in."
    else
        debug "Logging out of LastPass."

        lpass logout ${OVERWRITE_OPTION} ${COLOR_OPTION}
    fi
}

renameAttachment() {
    debug "Trying to rename attachment '${ATTACHMENT_FILE}'."

    MIME_TYPE=$(file -b --mime-type "${ATTACHMENT_FILE}")

    case "${MIME_TYPE}" in
        application/gzip | application/json | application/pdf | \
        application/rtf | application/zip | image/bmp | \
        image/gif | image/jpeg | image/png | image/tiff | \
        text/csv | text/html | text/plain | video/mp4 )
            EXTENSION=$(echo "${MIME_TYPE}" | cut -d '/' -f 2)
            ;;

        application/java-archive)
            EXTENSION='jar'
            ;;

        application/x-7z-compressed)
            EXTENSION='7z'
            ;;

        application/x-tar)
            EXTENSION='tar'
            ;;

        image/svg+xml)
            EXTENSION='svg'
            ;;

        *)
            EXTENSION=''

            debug "Unknown MIME type '${MIME_TYPE}'."
            ;;
    esac

    if [[ ! -z ${EXTENSION} ]]; then
        debug "Renaming attachment to '${ATTACHMENT_FILE}.${EXTENSION}'."

        mv "${ATTACHMENT_FILE}" "${ATTACHMENT_FILE}.${EXTENSION}"
    fi
}

exportAttachment() {
    if [[ -z ${ATTACHMENT_FILE} ]]; then
        ATTACHMENT_FILE=${ATTACHMENT_ID}

        TRY_RENAME='true'
    fi

    ATTACHMENT_FILE=${ATTACHMENTS_DIR}/${ATTACHMENT_FILE}

    if [[ -z ${ITEM_ID} ]] || [[ -z ${ATTACHMENT_ID} ]]; then
        debug "Missing attachment information '${ITEM_ID}' or '${ATTACHMENT_ID}'."
    else
        debug "Exporting attachment '${ATTACHMENT_ID}' to '${ATTACHMENT_FILE}'."

        lpass show ${ITEM_ID} --attach ${ATTACHMENT_ID} --quiet > "${ATTACHMENT_FILE}"
    fi

    if [[ ${TRY_RENAME} == 'true' ]]; then
        renameAttachment
    fi
}

exportItem() {
    debug "Exporting item '${ITEM_ID}' to '${OUTPUT_FILE}'."

    lpass show --json --all ${COLOR_OPTION} ${ITEM_ID} > "${OUTPUT_FILE}"

    while read -r LINE; do
        ATTACHMENTS_DIR=${OUTPUT_DIR}/${ITEM_ID}

        if [[ ! -d ${ATTACHMENTS_DIR} ]]; then
            debug "Making directory '${ITEM_ID}' for attachments."

            mkdir ${ATTACHMENTS_DIR}
        fi

        ATTACHMENT_ID=$(echo $LINE | cut -d ':' -f 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        ATTACHMENT_FILE=$(echo $LINE | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        exportAttachment
    done < <(lpass show ${COLOR_OPTION} ${ITEM_ID} | grep '^att-')
}

OUTPUT_DIR=$(realpath ${OUTPUT_DIR})

login

debug "Retrieving list of LastPass items."

ITEM_IDS=$(lpass ls -l --format '%ai' ${COLOR_OPTION})

NUM_ITEMS=$(echo ${ITEM_IDS} | wc -w)

debug "Found ${NUM_ITEMS} items."

for ITEM_ID in ${ITEM_IDS}; do
    OUTPUT_FILE=${OUTPUT_DIR}/${ITEM_ID}.json

    if [[ -s ${OUTPUT_FILE} ]]; then
        if [[ ! -z ${OVERWRITE_OPTION} ]]; then
            debug "Overwriting existing item '${OUTPUT_FILE}'."

            exportItem
        else
            debug "Item already exists '${OUTPUT_FILE}'. Use -f option to overwrite."
        fi
    else
        exportItem
    fi

    #showProgress
done

logout
