#!/usr/bin/env bash

set -o nounset

# enable extended pattern matching features
shopt -s extglob

usage() {
    cat << EOT 1>&2
Usage: export.sh [-dfhjnqs] [-a algo] [-c opt] [-e prog] [-i fn] [-k kdf] [-p fn] [-x ext] [-z fn] -u username dir

OPTIONS
=======
-a algo      use 'algo' for encryption; default: aes-256-cbc (OpenSSL), AES256 (GnuPG)
-c opt       color option: one of: auto, never, or always; default: never
-d           output debug information
-e prog      use 'prog' for encryption; either 'openssl' or 'gnupg'; default: openssl
-f           overwrite output and index files if they already exists
-h           show help
-i fn        write an index file to 'fn'
-j           write output using JSON format
-k kdf       use 'kdf' for key derivation function; default: pbkdf2 (OpenSSL), N/A (GnuPG)
-n           do not export items; typically used when you just want an index
-p fn        encrypt data; use 'fn' for passphrase file
-q           do not display status information
-s           stay logged in after script finishes
-u username  login to LastPass using username
-x ext       use 'ext' as extension for encrypted files; default: enc
-z fn        zip up the output directory to 'fn' using tar and gzip

ARGUMENTS
=========
dir          directory to write output files

EXAMPLES
========
# export LastPass items for myusername to /tmp/lpass directory in encrypted JSON format
$ export.sh -d -f -j -s -p passphrase.txt -u myusername /tmp/lpass

EOT

    exit
}

initGlobals() {
    declare -gA GLOBALS=(
        [BE_QUIET]='false'              # -q
        [COLOR_OPTION]=''               # -c
        [CREATE_INDEX]='false'          # -i
        [DEBUG]='false'                 # -d
        [EXPORT_ITEMS]='true'           # -n
        [ENCRYPT_DATA]='false'          # -p
        [ENCRYPTED_EXTENSION]=''        # -x
        [ENCRYPTION_ALGO]=''            # -a
        [ENCRYPTION_KDF]=''             # -k
        [ENCRYPTION_PROG]=''            # -e
        [INDEX_FILE]=''                 # -i
        [ITEM_EXTENSION]=''             # -x
        [JSON_OPTION]=''                # -j
        [OUTPUT_DIR]=''                 # dir
        [OVERWRITE_OPTION]=''           # -f
        [PASSPHRASE_FILE]=''            # -p
        [STAY_LOGGED_IN]='false'        # -s
        [USERNAME]=''                   # -u
        [ZIP_FILE]=''                   # -z
    )
}

debug() {
    if [[ ${GLOBALS[DEBUG]} == 'true' ]]; then
        echo "$@"
    fi
}

processOptions() {
    local FLAG
    local OPTARG
    local OPTIND

    [[ $# -eq 0 ]] && usage

    while getopts ":a:c:de:fhi:jk:np:qsu:x:z:" FLAG; do
        case "${FLAG}" in
            a)
                GLOBALS[ENCRYPTION_ALGO]=${OPTARG}

                debug "Encryption algorithm set to '${GLOBALS[ENCRYPTION_ALGO]}'."
                ;;

            c)
                if [[ ${OPTARG} == @(auto|never|always) ]]; then
                    GLOBALS[COLOR_OPTION]="--color=${OPTARG}"

                    debug "Setting color option to '${GLOBALS[COLOR_OPTION]}'."
                else
                    debug "Invalid color option '${OPTARG}'."
                fi
                ;;

            d)
                GLOBALS[DEBUG]='true'

                debug "Debug mode turned on."
                ;;

            e)
                GLOBALS[ENCRYPTION_PROG]=${OPTARG}

                debug "Encryption program set to '${GLOBALS[ENCRYPTION_PROG]}'."
                ;;

            f)
                GLOBALS[OVERWRITE_OPTION]='-f'

                debug "Force overwrite mode turned on."
                ;;

            i)
                GLOBALS[CREATE_INDEX]='true'

                debug "Create index mode turned on."

                GLOBALS[INDEX_FILE]=${OPTARG}

                debug "Index filename set to '${GLOBALS[INDEX_FILE]}'."
                ;;

            j)
                GLOBALS[JSON_OPTION]='--json'

                debug "JSON output format turned on."

                GLOBALS[ITEM_EXTENSION]='json'

                debug "Item extension set to '${GLOBALS[ITEM_EXTENSION]}'."
                ;;

            k)
                GLOBALS[ENCRYPTION_KDF]=${OPTARG}

                debug "Encryption key derivation function set to '${GLOBALS[ENCRYPTION_KDF]}'."
                ;;

            n)
                GLOBALS[EXPORT_ITEMS]='false'

                debug "Export items mode turned off."
                ;;

            p)
                GLOBALS[ENCRYPT_DATA]='true'

                debug "Encryption turned on."

                GLOBALS[PASSPHRASE_FILE]=${OPTARG}

                debug "Encryption passphrase file set to '${GLOBALS[PASSPHRASE_FILE]}'."
                ;;

            q)
                GLOBALS[BE_QUIET]='true'

                debug "Quiet mode turned on."
                ;;

            s)
                GLOBALS[STAY_LOGGED_IN]='true'

                debug "Stay logged in mode turned on."
                ;;

            u)
                GLOBALS[USERNAME]=${OPTARG}

                debug "Username set to '${GLOBALS[USERNAME]}'."
                ;;

            x)
                GLOBALS[ENCRYPTED_EXTENSION]=${OPTARG}

                debug "Encrypted extension set to '${GLOBALS[ENCRYPTED_EXTENSION]}'."
                ;;

            z)
                GLOBALS[ZIP_FILE]=${OPTARG}

                debug "Zip file set to '${GLOBALS[PASSPHRASE_FILE]}'."
                ;;

            h | *)
                usage
                ;;
        esac
    done

    shift $(( OPTIND - 1 ))

    [[ $# -eq 0 ]] && usage

    GLOBALS[OUTPUT_DIR]=$(realpath "$1")
}

validateInputs() {
    if [[ -z ${GLOBALS[USERNAME]} || -z ${GLOBALS[OUTPUT_DIR]} ]]; then
        echo "Missing username and/or output directory." > /dev/stderr

        usage
    fi

    if [[ ! -d ${GLOBALS[OUTPUT_DIR]} ]]; then
        echo "Output directory is not actually a directory." > /dev/stderr

        exit
    fi

    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' && ! -s ${GLOBALS[PASSPHRASE_FILE]} ]]; then
        echo "Encryption requested, but passphrase file does not exist or is empty." > /dev/stderr

        exit
    fi

    if [[ ${GLOBALS[EXPORT_ITEMS]} == 'false' && ${GLOBALS[CREATE_INDEX]} == 'false' ]]; then
        echo "Export items and create index modes are both disabled. Nothing to do." > /dev/stderr

        exit
    fi
}

setDefaults() {
    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
        if [[ -z ${GLOBALS[ENCRYPTION_PROG]} ]]; then
            GLOBALS[ENCRYPTION_PROG]='openssl'

            debug "Encryption program set to default of '${GLOBALS[ENCRYPTION_PROG]}'."
        fi

        if [[ -z ${GLOBALS[ENCRYPTION_ALGO]} ]]; then
            if [[ ${GLOBALS[ENCRYPTION_PROG]} == 'openssl' ]]; then
                GLOBALS[ENCRYPTION_ALGO]='aes-256-cbc'
            else
                GLOBALS[ENCRYPTION_ALGO]='AES256'
            fi

            debug "Encryption algorithm set to default of '${GLOBALS[ENCRYPTION_ALGO]}'."
        fi

        if [[ -z ${GLOBALS[ENCRYPTION_KDF]} ]]; then
            if [[ ${GLOBALS[ENCRYPTION_PROG]} == 'openssl' ]]; then
                GLOBALS[ENCRYPTION_KDF]='pbkdf2'
            else
                GLOBALS[ENCRYPTION_KDF]=''
            fi

            debug "Encryption key derivation function set to default of '${GLOBALS[ENCRYPTION_KDF]}'."
        fi

        if [[ -z ${GLOBALS[ENCRYPTED_EXTENSION]} ]]; then
            GLOBALS[ENCRYPTED_EXTENSION]='enc'

            debug "Encrypted extension set to default of '${GLOBALS[ENCRYPTED_EXTENSION]}'."
        fi
    fi

    if [[ -z ${GLOBALS[COLOR_OPTION]} ]]; then
        GLOBALS[COLOR_OPTION]='--color=never'

        debug "Color option set to default of '${GLOBALS[COLOR_OPTION]}'."
    fi

    if [[ -z ${GLOBALS[OVERWRITE_OPTION]} ]]; then
        GLOBALS[OVERWRITE_OPTION]=''

        debug "Overwrite option set to default of '${GLOBALS[OVERWRITE_OPTION]}'."
    fi

    if [[ -z ${GLOBALS[JSON_OPTION]} ]]; then
        GLOBALS[ITEM_EXTENSION]='txt'

        debug "Item extension set to default of '${GLOBALS[ITEM_EXTENSION]}'."

        GLOBALS[JSON_OPTION]=''

        debug "JSON option set to default of '${GLOBALS[JSON_OPTION]}'."
    fi
}

checkForDependency() {
    debug "Checking for dependency '$1'."

    if ! command -v "$1" &> /dev/null; then
        echo "Dependency '$1' is missing." > /dev/stderr

        exit
    fi
}

dependencyCheck() {
    local DEPENDENCY

    for DEPENDENCY in cat cut file grep lpass mkdir mv realpath sed wc; do
        checkForDependency "${DEPENDENCY}"
    done

    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
        if [[ ${GLOBALS[ENCRYPTION_PROG]} == 'openssl' ]]; then
            checkForDependency openssl
        else
            checkForDependency gpg
        fi
    fi

    if [[ -n ${GLOBALS[ZIP_FILE]} ]]; then
        checkForDependency tar
    fi
}

login() {
    debug "Logging into LastPass as '${GLOBALS[USERNAME]}'."

    # FIXME: Only login if not already logged in.

    lpass login "${GLOBALS[COLOR_OPTION]}" "${GLOBALS[USERNAME]}"
}

logout() {
    if [[ ${GLOBALS[STAY_LOGGED_IN]} == 'true' ]]; then
        debug "Staying logged in."
    else
        debug "Logging out of LastPass."

        lpass logout "${GLOBALS[OVERWRITE_OPTION]}" "${GLOBALS[COLOR_OPTION]}"
    fi
}

trim() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

cutAndTrim() {
    echo "$1" | cut -d "$2" -f "$3" | trim
}

determineMimeType() {
    # FIXME: Need to guess file type before encryption if un-named attachment without calling downloadAttachment twice

    downloadAttachment "$1" "$2" | file -b --mime-type -
}

determineExtension() {
    local EXTENSION

    case "$1" in
        application/gzip | application/json | application/pdf | \
        application/rtf | application/zip | image/bmp | \
        image/gif | image/jpeg | image/png | image/tiff | \
        text/csv | text/html | text/plain | video/mp4 )
            EXTENSION=$(cutAndTrim "$1" / 2)
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
            ;;
    esac

    echo "${EXTENSION}"
}

encryptData() {
    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
        if [[ ${GLOBALS[ENCRYPTION_PROG]} == 'openssl' ]]; then
            openssl enc -"${GLOBALS[ENCRYPTION_ALGO]}" -provider default -"${GLOBALS[ENCRYPTION_KDF]}" -pass file:"${GLOBALS[PASSPHRASE_FILE]}"
        else
            gpg --quiet --batch --passphrase-file "${GLOBALS[PASSPHRASE_FILE]}" --symmetric --cipher-algo "${GLOBALS[ENCRYPTION_ALGO]}"
        fi
    else
        cat
    fi
}

downloadAttachment() {
    lpass show "${GLOBALS[COLOR_OPTION]}" "$1" --attach "$2" --quiet
}

exportItemAttachment() {
    local ATTACHMENTS_DIR
    local ATTACHMENT_ID
    local ATTACHMENT_FILE
    local MIME_TYPE
    local UNNAMED_ATTACHMENT
    local EXTENSION

    ATTACHMENTS_DIR=${GLOBALS[OUTPUT_DIR]}/$1

    if [[ ! -d ${ATTACHMENTS_DIR} ]]; then
        debug "Making directory '$1' for item attachments."

        mkdir "${ATTACHMENTS_DIR}"
    fi

    ATTACHMENT_ID=$(cutAndTrim "$2" : 1)
    ATTACHMENT_FILE=$(cutAndTrim "$2" : 2)

    if [[ -z $1 || -z ${ATTACHMENT_ID} ]]; then
        debug "Missing attachment information '$1' or '${ATTACHMENT_ID}'."

        return
    fi

    if [[ -z ${ATTACHMENT_FILE} ]]; then
        # handle un-named attachments
        ATTACHMENT_FILE=${ATTACHMENT_ID}

        UNNAMED_ATTACHMENT='true'

        MIME_TYPE=$(determineMimeType "$1" "${ATTACHMENT_ID}")

        debug "MIME type for '${ATTACHMENT_ID}' is '${MIME_TYPE}'."

        EXTENSION=$(determineExtension "${MIME_TYPE}")

        debug "Extension for '${MIME_TYPE}' set to '${EXTENSION}'."
    else
        UNNAMED_ATTACHMENT='false'
    fi

    ATTACHMENT_FILE=${ATTACHMENTS_DIR}/${ATTACHMENT_FILE}

    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
        if [[ ${UNNAMED_ATTACHMENT} == 'true' ]]; then
            EXTENSION=${EXTENSION}.${GLOBALS[ENCRYPTED_EXTENSION]}
        else
            EXTENSION=${GLOBALS[ENCRYPTED_EXTENSION]}
        fi
    fi

    if [[ -n ${EXTENSION} ]]; then
        ATTACHMENT_FILE=${ATTACHMENT_FILE}.${EXTENSION}

        debug "Updating ATTACHMENT_FILE to '${ATTACHMENT_FILE}'."
    fi

    debug "Exporting attachment '${ATTACHMENT_ID}' to '${ATTACHMENT_FILE}'."

    downloadAttachment "$1" "${ATTACHMENT_ID}" | encryptData > "${ATTACHMENT_FILE}"
}

listAttachments() {
    lpass show "${GLOBALS[COLOR_OPTION]}" "$1" | grep '^att-'
}

exportItem() {
    debug "Exporting item '$1' to '$2'."

    lpass show "${GLOBALS[JSON_OPTION]}" --all "${GLOBALS[COLOR_OPTION]}" "$1" | encryptData > "$2"

    while read -r LINE; do
        exportItemAttachment "$1" "${LINE}"
    done < <(listAttachments "$1")
}

showProgress() {
    if [[ ${GLOBALS[BE_QUIET]} != 'true' ]]; then
        debug "Processed $1 of $2."
    fi
}

performSetup() {
    initGlobals

    processOptions "$@"

    validateInputs

    setDefaults

    dependencyCheck

    if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
        GLOBALS[ITEM_EXTENSION]=${GLOBALS[ITEM_EXTENSION]}.${GLOBALS[ENCRYPTED_EXTENSION]}

        debug "Item extension set to '${GLOBALS[ITEM_EXTENSION]}'."
    fi
}

createIndex() {
    local INDEX_FILE

    if [[ ${GLOBALS[CREATE_INDEX]} == 'true' ]]; then
        debug "Creating index of LastPass items."

        INDEX_FILE=${GLOBALS[OUTPUT_DIR]}/${GLOBALS[INDEX_FILE]}

        if [[ ${GLOBALS[ENCRYPT_DATA]} == 'true' ]]; then
            INDEX_FILE=${INDEX_FILE}.${GLOBALS[ENCRYPTED_EXTENSION]}
        fi

        debug "Index file set to '${INDEX_FILE}'."

        if [[ -s ${INDEX_FILE} && -z ${GLOBALS[OVERWRITE_OPTION]} ]]; then
            debug "Index file already exists '${INDEX_FILE}'. Use -f option to overwrite."
        else
            echo "$1" | encryptData > "${INDEX_FILE}"
        fi
    fi
}

exportAllItems() {
    local ITEM_IDS
    local NUM_ITEMS
    local ITEM_COUNTER
    local ITEM_ID
    local OUTPUT_FILE

    if [[ ${GLOBALS[EXPORT_ITEMS]} == 'true' ]]; then
        debug "Exporting items."

        ITEM_IDS=$(echo "$1" | cut -d '|' -f 1)

        NUM_ITEMS=$(echo -n "$1" | wc -l | trim)

        if [[ ${NUM_ITEMS} -gt 0 ]]; then
            debug "Found ${NUM_ITEMS} items."

            ITEM_COUNTER=0

            for ITEM_ID in ${ITEM_IDS}; do
                    OUTPUT_FILE=${GLOBALS[OUTPUT_DIR]}/${ITEM_ID}.${GLOBALS[ITEM_EXTENSION]}

                    if [[ -s ${OUTPUT_FILE} && -z ${GLOBALS[OVERWRITE_OPTION]} ]]; then
                        debug "Item already exists '${OUTPUT_FILE}'. Use -f option to overwrite."
                    else
                        exportItem "${ITEM_ID}" "${OUTPUT_FILE}"
                    fi

                (( ITEM_COUNTER++ ))

                showProgress "${ITEM_COUNTER}" "${NUM_ITEMS}"
            done
        else
            debug "No items found for '${GLOBALS[USERNAME]}'."
        fi
    fi
}

zipOutputDirectory() {
    if [[ -n ${GLOBALS[ZIP_FILE]} ]]; then
        debug "Zipping output directory to '${GLOBALS[ZIP_FILE]}'."

        tar --create --gzip --file "${GLOBALS[ZIP_FILE]}" --directory "${GLOBALS[OUTPUT_DIR]}" .
    fi
}

exportVault() {
    local ITEMS

    login

    debug "Retrieving list of LastPass items."

    ITEMS=$(lpass ls --long --format '%ai|%an|%au|%aN' "${GLOBALS[COLOR_OPTION]}")

    createIndex "${ITEMS}"

    exportAllItems "${ITEMS}"

    zipOutputDirectory

    logout
}

performSetup "$@"

exportVault
