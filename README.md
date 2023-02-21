# lastpass-export
Export items with attachments from LastPass. 

## Overview
This script will export items along with their associated attachments
from your LastPass vault to a directory on disk.

## Execution
To execute this script, run the following commands once the
dependencies are installed:

```sh
# list possble options and help
$ export.sh -h

# export LastPass items for myusername to /tmp/lpass directory in encrypted JSON format
$ export.sh -d -f -j -s -p passphrase.txt -u myusername /tmp/lpass
```

## Dependencies
- cat - pre-installed with macOS and most Linux distributions
- cut - pre-installed with macOS and most Linux distributions
- file - pre-installed with macOS and most Linux distributions
- gpg - GNU Privacy Guard; install using [Homebrew](https://formulae.brew.sh/formula/gnupg), another package manager or [manually](https://gnupg.org/).
- grep - pre-installed with macOS and most Linux distributions
- lpass - LastPass CLI; install using [Homebrew](https://formulae.brew.sh/formula/lastpass-cli), another package manager or [manually](https://github.com/lastpass/lastpass-cli).
- mkdir - pre-installed with macOS and most Linux distributions
- mv - pre-installed with macOS and most Linux distributions
- realpath - install via coreutils using [Homebrew](https://formulae.brew.sh/formula/coreutils), another package manager or [manually](https://www.gnu.org/software/coreutils/).
- sed - pre-installed with macOS and most Linux distributions
- wc - pre-installed with macOS and most Linux distributions

## Platform Support
This script was tested on macOS Monterey (12.6) using GNU Bash 5.2.15,
but should work on any GNU/Linux system that supports the dependencies
above.
