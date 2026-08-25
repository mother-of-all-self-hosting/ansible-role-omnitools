<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024, 2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024, 2025 Suguru Hirahara
SPDX-FileCopyrightText: 2026 Daniel Warhammar

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up OmniTools

This is an [Ansible](https://www.ansible.com/) role which installs [OmniTools](https://github.com/iib0011/omni-tools) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

OmniTools is a self-hosted web app offering a variety of online tools to simplify everyday tasks. All files are processed entirely on the client side.

See the project's [documentation](https://github.com/iib0011/omni-tools/blob/main/README.md) to learn what OmniTools does and why it might be useful to you.

## Adjusting the playbook configuration

To enable OmniTools with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# omnitools                                                            #
#                                                                      #
########################################################################

omnitools_enabled: true

########################################################################
#                                                                      #
# /omnitools                                                           #
#                                                                      #
########################################################################
```

### Set the hostname

To enable OmniTools you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
omnitools_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Building the container image yourself

By default the role installs the container image that the OmniTools project publishes. Setting `omnitools_container_image_self_build: true` makes it clone the project at the tag matching `omnitools_version` and build an image on the server instead.

The image this builds is deliberately not the same as the published one. Upstream's Dockerfile serves the built site with [nginx](https://nginx.org/) running as `root`; the role renders [its own Dockerfile](../templates/Dockerfile.j2) over it and serves the site with [Static Web Server](https://static-web-server.net/) instead, which is what lets the container run as an unprivileged user with a read-only root filesystem and no added Linux capabilities.

Two consequences are worth knowing about:

- the `omnitools_environment_variables_server_*` settings configure Static Web Server, so they only have an effect when self-building. The published image ignores them.
- `omnitools_container_http_port` is 8080 when self-building and 80 otherwise, and neither is a free choice: nginx in the published image listens on port 80 and cannot be told otherwise. The role refuses to install with any other value on that path, rather than publishing a port with nothing behind it.

Building the front-end takes a while and needs considerably more memory than serving it does, so on a small server the published image is the better option.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `omnitools_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, OmniTools becomes available at the specified hostname like `https://example.com`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu omnitools` (or how you/your playbook named the service, e.g. `mash-omnitools`).
