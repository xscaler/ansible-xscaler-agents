#!/bin/sh
# Generates a minimal inventory and group_vars from env vars, then runs the
# Linux agent playbook. Users can mount a custom inventory instead of setting
# TARGET_HOSTS — see install.sh for examples.
set -eu

# -- required ------------------------------------------------------------------
: "${XSCALER_TOKEN:?XSCALER_TOKEN is required (xse_...)}"

# -- optional ------------------------------------------------------------------
XSCALER_OPAMP_ENDPOINT="${XSCALER_OPAMP_ENDPOINT:-wss://agents.xscalerlabs.com/v1/opamp}"
XSCALER_ENV="${XSCALER_ENV:-prod}"
XSCALER_REGION="${XSCALER_REGION:-us}"
ANSIBLE_USER="${ANSIBLE_USER:-}"
ANSIBLE_SSH_PASS="${ANSIBLE_SSH_PASS:-}"
CHECK="${CHECK:-false}"
VERIFY="${VERIFY:-false}"
INVENTORY_PATH="/workspace/inventories/prod/hosts.yml"

# -- build inventory from TARGET_HOSTS if no inventory is mounted --------------
if [ ! -f "${INVENTORY_PATH}" ]; then
    : "${TARGET_HOSTS:?Either mount an inventory at ${INVENTORY_PATH} or set TARGET_HOSTS=host1,host2}"
    mkdir -p "$(dirname "${INVENTORY_PATH}")"
    printf 'linux_hosts:\n  hosts:\n' > "${INVENTORY_PATH}"

    # Support user@host format — extract user into ansible_user per host
    echo "${TARGET_HOSTS}" | tr ',' '\n' | while IFS= read -r entry; do
        entry="$(echo "${entry}" | tr -d ' ')"
        [ -z "${entry}" ] && continue
        if echo "${entry}" | grep -q '@'; then
            host_user="$(echo "${entry}" | cut -d@ -f1)"
            host_addr="$(echo "${entry}" | cut -d@ -f2)"
            printf '    %s:\n      ansible_user: "%s"\n' "${host_addr}" "${host_user}"
        else
            printf '    %s:\n' "${entry}"
        fi
    done >> "${INVENTORY_PATH}"
fi

# -- write vars ----------------------------------------------------------------
mkdir -p /workspace/inventories/prod/group_vars/all
cat > /workspace/inventories/prod/group_vars/all/vars.yml <<EOF
xscaler_enrollment_token: "${XSCALER_TOKEN}"
xscaler_opamp_endpoint: "${XSCALER_OPAMP_ENDPOINT}"
xscaler_agent_labels:
  environment: "${XSCALER_ENV}"
  region: "${XSCALER_REGION}"
EOF

# Write SSH password into vars if provided (kept out of CLI args to avoid
# appearing in process listings)
if [ -n "${ANSIBLE_SSH_PASS}" ]; then
    cat >> /workspace/inventories/prod/group_vars/all/vars.yml <<EOF
ansible_password: "${ANSIBLE_SSH_PASS}"
ansible_become_password: "${ANSIBLE_SSH_PASS}"
EOF
fi

# -- SSH key: copy from read-only mount to writable temp path ------------------
SSH_KEY_ARG=""
if [ -f /root/.ssh/id_rsa ]; then
    cp /root/.ssh/id_rsa /tmp/ansible_id_rsa
    chmod 600 /tmp/ansible_id_rsa
    SSH_KEY_ARG="--private-key /tmp/ansible_id_rsa"
fi

# -- build playbook args -------------------------------------------------------
if [ "${VERIFY}" = "true" ]; then
    PLAYBOOK="playbooks/verify.yml"
else
    PLAYBOOK="playbooks/linux-agents.yml"
fi
set -- -i "${INVENTORY_PATH}" "${PLAYBOOK}"

[ "${CHECK}" = "true" ]  && set -- "$@" --check
[ -n "${ANSIBLE_USER}" ] && set -- "$@" -u "${ANSIBLE_USER}"
# shellcheck disable=SC2086
[ -n "${SSH_KEY_ARG}" ]  && set -- "$@" ${SSH_KEY_ARG}

exec ansible-playbook "$@"
