```ini {"id":"01J49XJMP7ZCVW77F4M3KGT9SM"}
# PiHA-Deployer Node-RED

## Overview

PiHA-Deployer Node-RED is a part of the PiHA-Deployer project, designed to automate the setup of Node-RED and Portainer on a Raspberry Pi for home automation purposes. This script simplifies the process of installing and configuring Docker, Node-RED, Portainer, and Samba sharing.

## Contents

- `install-node-red.sh`: The main installation script.
- `PiHA-Deployer-NodeRED.sh`: The deployment script for Node-RED and Portainer.
- `docker-compose.yml`: Docker Compose file for Node-RED and Portainer services.

## What It Does

1. Sets up environment variables interactively.
2. Installs Docker and Docker Compose.
3. Sets up Samba for folder sharing.
4. Deploys Node-RED and Portainer using Docker Compose.
5. Configures networking and permissions.

## How to Run

1. Ensure you have a Raspberry Pi with a fresh Raspberry Pi OS installation.

2. Run the following command to start the installation:
curl -sSL "https://raw.githubusercontent.com/cdelalama/PiHA-Deployer/main/node-red/install-node-red.sh" | bash

3. Follow the prompts to set up your environment variables.

4. The script will automatically download necessary files and execute the main deployment script.

## Post-Installation

- Access Node-RED at `http://<Your-Pi-IP>:<NODE_RED_PORT>`
- Access Portainer at `http://<Your-Pi-IP>:<PORTAINER_PORT>`
- Access shared Docker folders via Samba at `\\<Your-Pi-IP>\docker`

## Notes

- The installation process may take several minutes depending on your internet connection and Raspberry Pi model.
- Ensure your Raspberry Pi is connected to the internet before starting the installation.
- The script will prompt for sudo permissions as needed.

## Troubleshooting

If you encounter any issues, check the Docker logs:
docker logs portainer
docker logs node-red

## Security

- The script sets up a Samba share. Ensure you use a strong password when prompted.
- The .env file containing sensitive information is deleted after setup for security reasons.

## Contributing

Feel free to fork this repository and submit pull requests for any enhancements.

## License

[Insert your license information here]
```

```ini {"id":"01J4AKZ32QN4JV2G1AVYS7DY12"}

```