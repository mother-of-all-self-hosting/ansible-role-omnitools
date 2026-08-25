<!--
SPDX-FileCopyrightText: 2018-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently there are two testing scenarios available.

### `default`

Tests a standard OmniTools installation, using the container image that the OmniTools project publishes.

OmniTools is a browser-side application: everything it does happens in JavaScript in the visitor's browser, and the container is a web server handing out a directory of static files. There is no server-side round trip to exercise, so this scenario checks the things a static file server can get wrong — that the running container is the version `omnitools_version` names, that the hashed application bundle is the real file rather than the fallback document, that deep links reach the application shell, that the published port maps onto the port the server listens on, and that the environment file and Traefik labels the role renders reach the container.

Note that the image answers **every** path with 200 and the application shell (nginx `try_files`), so status codes are never load-bearing here.

### `default-selfbuild`

Tests an installation which builds the container image on the server (`omnitools_container_image_self_build: true`).

Self-building produces a different image from the published one — the role renders its own Dockerfile over upstream's and serves the site with Static Web Server rather than nginx — so this scenario verifies what only self-building can get wrong: that the source tree is at the git tag the version names, that the role's Dockerfile really replaced upstream's, that the `SERVER_*` variables reach the server (they are live here and inert on the published image), and that the container keeps its unprivileged user, read-only root filesystem and dropped capabilities.

Building the front-end from source is by far the slowest job in CI, and it only changes behavior when a version in `defaults/main.yml` changes, so the workflow gates it on such a bump and on `workflow_dispatch`. Run it by hand whenever `templates/Dockerfile.j2` or the self-build tasks change.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default

molecule test --scenario-name default-selfbuild
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
