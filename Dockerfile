# syntax=docker/dockerfile:1
# xScaler agent installer — runs Ansible inside Docker so the user needs no
# local Ansible install. Pass target hosts + token via env vars or mount an
# existing inventory. See install.sh for the one-liner wrapper.

FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "ansible-core==2.17.*"

WORKDIR /workspace

COPY requirements.yml .
RUN ansible-galaxy collection install -r requirements.yml

COPY ansible.cfg .
COPY playbooks/ playbooks/
COPY roles/ roles/
COPY inventories/sample/ inventories/sample/

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
