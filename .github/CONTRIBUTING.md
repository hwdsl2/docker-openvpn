# Contributing

Thanks for helping improve this project. This repository maintains the Docker image for OpenVPN; bare-metal install script changes belong in [openvpn-install](https://github.com/hwdsl2/openvpn-install).

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- For upstream OpenVPN or EasyRSA behavior, check the upstream project first.
- Do not include private keys, client certificates, `.ovpn` files, env secrets, VPN credentials, or logs with secrets.

## Pull Requests

- Update `README.md`, env examples, or compose examples when behavior changes.
- Include the Docker host OS, architecture, image tag, and start method tested.
- Note the OpenVPN protocol/port and client app tested when relevant.

## Testing

Test the smallest relevant path before opening a PR, for example:

- Build or run the image when Dockerfile/runtime behavior changes.
- Exercise client creation/export/revoke paths when client management changes.
- Verify container logs and OpenVPN service startup when runtime scripts change.
- Run ShellCheck when editing shell scripts.
