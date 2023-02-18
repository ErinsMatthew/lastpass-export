# lastpass-export
Export items with attachments from LastPass. 

## Overview
This script will export items along with their associated attachments
from your LastPass vault to a directory on disk.

## Execution
To execute this script, run the following commands once the
dependencies are installed:

```sh
# export LastPass items for myusername to /tmp/lpass
$ export.sh -d -f -s -u myusername /tmp/lpass
```

## Dependencies
- cat - pre-installed with macOS and most Linux distributions
- cut - pre-installed with macOS and most Linux distributions
- file - pre-installed with macOS and most Linux distributions
- grep - pre-installed with macOS and most Linux distributions
- lpass - LastPass CLI; install using [Homebrew](https://formulae.brew.sh/formula/lastpass-cli), another package manager or [manually](https://github.com/lastpass/lastpass-cli).
- realpath - install via coreutils using [Homebrew](https://formulae.brew.sh/formula/coreutils), another package manager or [manually](https://www.gnu.org/software/coreutils/).
- sed - pre-installed with macOS and most Linux distributions

## Platform Support
This script was tested on macOS Monterey (12.6) using GNU Bash 5.2.15,
but should work on any GNU/Linux system that supports the dependencies
above.
## TODO
- [ ] Encryption at rest.
- [ ] Show progress.
