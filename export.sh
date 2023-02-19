#!/bin/bash

# enable extended pattern matching features
shopt -s extglob

usage() {
    cat << EOT 1>&2
Usage: export.sh [-dfhjqs] [-c opt] -u username dir

OPTIONS
=======
-c opt       color option: one of: auto, never, or always
-d           output debug information
-f           overwrite output file if it already exists
-h           show help
-j           write output using JSON format
-q           do not display status information
-s           stay logged in after script finishes
-u username  login to LastPass using username

ARGUMENTS
=========
dir          directory to write output files

EXAMPLES
========
# export LastPass items for myusername to /tmp/lpass directory in JSON format
$ export.sh -d -f -j -s -u myusername /tmp/lpass

EOT

    exit
}

[[ $# -eq 0 ]] && usage

debug() {
    if [[ ${DEBUG} == 'true' ]]; then
        echo $*
    fi
}

while getopts ":c:dfhjqsu:" FLAG; do
    case "${FLAG}" in
        c)
            if [[ ${OPTARG} == @(auto|never|always) ]]; then
                COLOR_OPTION="--color=${OPTARG}"

                debug "Setting color option to '${OPTARG}'."
            else
                debug "Invalid color option '${OPTARG}'."
            fi
            ;;

        d)
            DEBUG='true'

            debug "Debug mode turned on."
            ;;

        f)
            OVERWRITE_OPTION='-f'

            debug "Force overwrite mode turned on."
            ;;

        j)
            ITEM_EXTENSION='json'
            JSON_OPTION='--json'

            debug "JSON output format turned on."
            ;;

        q)
            BE_QUIET='true'

            debug "Quiet mode turned on."
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

if [[ -z ${USERNAME} || -z ${OUTPUT_DIR} ]]; then
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

    if [[ -z ${JSON_OPTION} ]]; then
        ITEM_EXTENSION='txt'

        debug "Item extension set to default of '${ITEM_EXTENSION}'."

        JSON_OPTION=''

        debug "JSON option set to default of '${JSON_OPTION}'."
    fi
}

setDefaults

dependencyCheck() {
    for DEPENDENCY in cat cut file grep lpass mkdir mv realpath sed wc; do
        debug "Checking for dependency '${DEPENDENCY}'."

        if ! command -v ${DEPENDENCY} &> /dev/null; then
            echo "Dependency '${DEPENDENCY}' is missing." > /dev/stderr

            exit
        fi
    done
}

dependencyCheck

login() {
    debug "Logging into LastPass as '${USERNAME}'."

    lpass login ${OVERWRITE_OPTION} ${COLOR_OPTION} $USERNAME
}

logout() {
    if [[ ${STAY_LOGGED_IN} == 'true' ]]; then
        debug "Staying logged in."
    else
        debug "Logging out of LastPass."

        lpass logout ${OVERWRITE_OPTION} ${COLOR_OPTION}
    fi
}

cutAndTrim() {
    echo "$1" | cut -d $2 -f $3 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

renameAttachment() {
    debug "Trying to rename attachment '${ATTACHMENT_FILE}'."

    MIME_TYPE=$(file -b --mime-type "${ATTACHMENT_FILE}")

    case "${MIME_TYPE}" in
        application/gzip | application/json | application/pdf | \
        application/rtf | application/zip | image/bmp | \
        image/gif | image/jpeg | image/png | image/tiff | \
        text/csv | text/html | text/plain | video/mp4 )
            EXTENSION=$(cutAndTrim "${MIME_TYPE}" / 2)
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

    if [[ -n ${EXTENSION} ]]; then
        debug "Renaming attachment to '${ATTACHMENT_FILE}.${EXTENSION}'."

        mv "${ATTACHMENT_FILE}" "${ATTACHMENT_FILE}.${EXTENSION}"
    fi
}

exportAttachment() {
    if [[ -z ${ATTACHMENT_FILE} ]]; then
        # handle un-named attachments
        ATTACHMENT_FILE=${ATTACHMENT_ID}

        TRY_RENAME='true'
    fi

    ATTACHMENT_FILE=${ATTACHMENTS_DIR}/${ATTACHMENT_FILE}

    if [[ -z ${ITEM_ID} || -z ${ATTACHMENT_ID} ]]; then
        debug "Missing attachment information '${ITEM_ID}' or '${ATTACHMENT_ID}'."
    else
        debug "Exporting attachment '${ATTACHMENT_ID}' to '${ATTACHMENT_FILE}'."

        lpass show ${COLOR_OPTION} ${ITEM_ID} --attach ${ATTACHMENT_ID} --quiet > "${ATTACHMENT_FILE}"
    fi

    if [[ ${TRY_RENAME} == 'true' ]]; then
        renameAttachment
    fi
}

exportItem() {
    debug "Exporting item '${ITEM_ID}' to '${OUTPUT_FILE}'."

    lpass show ${JSON_OPTION} --all ${COLOR_OPTION} ${ITEM_ID} > "${OUTPUT_FILE}"

    # export item attachments
    while read -r LINE; do
        ATTACHMENTS_DIR=${OUTPUT_DIR}/${ITEM_ID}

        if [[ ! -d ${ATTACHMENTS_DIR} ]]; then
            debug "Making directory '${ITEM_ID}' for item attachments."

            mkdir ${ATTACHMENTS_DIR}
        fi

        ATTACHMENT_ID=$(cutAndTrim "${LINE}" : 1)
        ATTACHMENT_FILE=$(cutAndTrim "${LINE}" : 2)

        exportAttachment
    done < <(lpass show ${COLOR_OPTION} ${ITEM_ID} | grep '^att-')
}

showProgress() {
    debug "Processed ${ITEM_COUNTER} of ${NUM_ITEMS}."
}

OUTPUT_DIR=$(realpath ${OUTPUT_DIR})

login

debug "Retrieving list of LastPass items."

ITEM_IDS=$(lpass ls -l --format '%ai' ${COLOR_OPTION})

NUM_ITEMS=$(echo ${ITEM_IDS} | wc -w)

if [[ ${NUM_ITEMS} -gt 0 ]]; then
    debug "Found ${NUM_ITEMS} items."

    ITEM_COUNTER=0

    for ITEM_ID in ${ITEM_IDS}; do
        OUTPUT_FILE=${OUTPUT_DIR}/${ITEM_ID}.${ITEM_EXTENSION}

        if [[ -s ${OUTPUT_FILE} && -z ${OVERWRITE_OPTION} ]]; then
            debug "Item already exists '${OUTPUT_FILE}'. Use -f option to overwrite."
        else
            exportItem
        fi

        $(( ITEM_COUNTER++ ))

        if [[ -z ${BE_QUIET} ]]; then
            showProgress
        fi
    done
else
    debug "No items found for '${USERNAME}'."
fi

logout
