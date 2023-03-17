# lastpass-export

Export items and their attachments from LastPass.

## Overview

This script will export items along with their associated attachments
from your LastPass vault to a directory on disk.

The contents can be optionally encrypted using GNU Privacy Guard (GPG).

## Execution

To execute this script, run the following commands once the
dependencies are installed:

```sh
# list possible options and help
$ export.sh -h

# export LastPass items for myusername to /tmp/lpass directory in encrypted JSON format
$ export.sh -dfjs -p passphrase.txt -u myusername /tmp/lpass

# or possibly using `caffeinate` if you have a large vault or a slow connection
$ caffeinate export.sh -dfjs -p passphrase.txt -u myusername /tmp/lpass

# export LastPass index file for myusername to /tmp/lpass directory in encrypted format
$ export.sh -ds -i index.txt -p passphrase.txt -u myusername /tmp/lpass

# export LastPass index file for myusername to /tmp/lpass directory in encrypted format and then zip it up into a tarball
$ export.sh -ds -i index.txt -z lpass.tar.gz -p passphrase.txt -u myusername /tmp/lpass
```

## Index File

If you include the `-i` option when running the command, the script will create
an index file in the output directory in the format below.  It will be encrypted
if encryption options are turned on.

```text
<Item ID>|<Item Name>|<Item Full Name>
```

## Decryption

If you chose to encrypt your vault items and attachments, you can decrypt
them using a command like:

```sh
# decrypt vault item file using same passphrase as above
$ gpg --quiet --batch --passphrase-file passphrase.txt --decrypt vaultItem.json.enc > vaultItem.json
```

## Dependencies

- `cat` - pre-installed with macOS and most Linux distributions
- `cut` - pre-installed with macOS and most Linux distributions
- `file` - pre-installed with macOS and most Linux distributions
- `gpg` - optional; GNU Privacy Guard; install using [Homebrew](https://formulae.brew.sh/formula/gnupg), another package manager, or [manually](https://gnupg.org/).
- `grep` - pre-installed with macOS and most Linux distributions
- `lpass` - LastPass CLI; install using [Homebrew](https://formulae.brew.sh/formula/lastpass-cli), another package manager, or [manually](https://github.com/lastpass/lastpass-cli).
- `mkdir` - pre-installed with macOS and most Linux distributions
- `mv` - pre-installed with macOS and most Linux distributions
- `realpath` - install via coreutils using [Homebrew](https://formulae.brew.sh/formula/coreutils), another package manager, or [manually](https://www.gnu.org/software/coreutils/).
- `sed` - pre-installed with macOS and most Linux distributions
- `wc` - pre-installed with macOS and most Linux distributions

## Platform Support

This script was tested on macOS Monterey (12.6) using GNU Bash 5.2.15,
but should work on any GNU/Linux system that supports the dependencies
above.
