# satyrographos
A naive package manager for SATySFi.

_WARNING: Command line interfaces except for `satyrographos install` are EXPERIMENTAL and subject to change and removal._

Currently, it only composes `~/.opam/<ocaml-version>/share/satysfi/<package>` installed by OPAM and user-defined packages under `~/.satyrographos/packages/<package>` and copy into ``~/.satysfi/dist`.

Satyrographos simplifies installation of SATySFi. For example, @zr-tex8r’s (`make-satysfi.sh`)[https://gist.github.com/zr-tex8r/0ab0d24255ecf631692c1f0cbc5ca026] will be like this.

```sh
#!/bin/bash
set -eux

sudo apt -y update
sudo apt -y install build-essential git m4 unzip curl ruby

yes '' | sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)

opam init --auto-setup --comp 4.06.0 --disable-sandboxing
eval $(opam env)
opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
opam update

opam install -y satysfi
opam install -y satyrographos

satyrographos install
```

## How Does It Works?
It copies all files under `~/.opam/<ocaml-version>/share/satysfi/<package>` and  `~/.satyrographos/packages/<package>` and copy into `~/.satysfi/dist`.

Except for duplication detection and hash file merging, `satyrographos install` behaves as
```sh
$ cp -r "$(opam var share)"/share/satysfi/*/* ~/.satysfi/dist
$ cp -r ~/.satyrographos/packages/*/* ~/.satysfi/dist
```

## Register Libraries
You can add a new library for SATySFi as an OPAM library or a directory under `~/.satyrographos`.

In this section, we are going to register a new library `great-package` like this.
```
- ~/src/
  - great-package/
    - hash/
      - fonts.satysfi-hash
    - fonts/
      - interesting-font.ttf
    - packages/
      - your-great.package.satyh
```

### Local Directory
Register your local library with `satyrographos pin add <local-dir>`.
```
$ satyrographos pin add ~/src/great-package
$ satyrographos install
```

### OPAM Package
Create a new package which installs the file into `<prefix>/usr/share/satysfi/great-package/packages/your-great-package.satyh`.

Examples:
- SATySFi-fonts-theano: https://github.com/na4zagin3/SATySFi-fonts-theano
