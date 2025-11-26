#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"

# Ensure we build the flows in the test namespaces
oc project $NS_TEST

# Build flows from folder where source code is located
cd /projects/workshop/tools/test/flows


# Where to call (change namespace if needed)
DOCSERVER_URL="http://docserver.webapp.svc:80"

# Fetch token,userId in one shot
echo "Fetching Rocket.Chat credentials from $DOCSERVER_URL ..."
RESPONSE=$(curl -sSf "$DOCSERVER_URL/configuration/rocketchat/$TEST_USER")   # -s silent, -S show errors, -f fail on HTTP errors

echo "response was: $RESPONSE"

# Split the response on the comma
IFS=',' read -r ROCKETCHAT_TOKEN ROCKETCHAT_USERID <<< "$RESPONSE"

# Sanity check
if [[ -z "$ROCKETCHAT_TOKEN" || -z "$ROCKETCHAT_USERID" ]]; then
  echo "ERROR: Invalid response from docserver: '$RESPONSE'" >&2
  exit 1
fi

echo "Got token: ${ROCKETCHAT_TOKEN:0:10}... and userId: $ROCKETCHAT_USERID"


# Fetch token,userId in one shot
echo "Fetching Matrix credentials from $DOCSERVER_URL ..."
RESPONSE=$(curl -sSf "$DOCSERVER_URL/configuration/matrix/$TEST_USER")   # -s silent, -S show errors, -f fail on HTTP errors

echo "response was: $RESPONSE"

# Split the response on the comma
IFS=',' read -r MATRIX_TOKEN MATRIX_ROOM <<< "$RESPONSE"

# Sanity check
if [[ -z "$MATRIX_TOKEN" || -z "$MATRIX_ROOM" ]]; then
  echo "ERROR: Invalid response from docserver: '$RESPONSE'" >&2
  exit 1
fi

echo "Got token: $MATRIX_TOKEN and userId: $MATRIX_ROOM"

cat > application.properties <<EOF
# Matrix credentials
matrix.token=$MATRIX_TOKEN
matrix.room=$MATRIX_ROOM

# Rocket.Chat credentials
rocketchat.token=$ROCKETCHAT_TOKEN
rocketchat.userid=$ROCKETCHAT_USERID
EOF

camel kubernetes run m2k/* \
application.properties \
--name m2k \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

camel kubernetes run k2r/* \
application.properties \
--name k2r \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift \
--env RC_ROOM=$TEST_ROOM

camel kubernetes run r2k/* \
application.properties \
--name r2k \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

camel kubernetes run k2m/* \
application.properties \
--name k2m \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

info "Flows have been built and deployed in: $NS_TEST"


# The following section of the script forces the deployments to be present in all worker nodes.
# This allows each worker node to gain authenticated access to master test images built in the host test namespace.

# Get all READY worker nodes, sorted alphabetically
mapfile -t WORKER_NODES < <(oc get nodes -l node-role.kubernetes.io/worker= --no-headers | awk '{print $1}' | sort)

# Test deployments
DEPLOYMENTS=(
    "m2k"
    "r2k"
    "k2m"
    "k2r"
)

# List worker nodes
echo "Found ${#WORKER_NODES[@]} worker nodes. Assigning round-robin..."

for i in "${!DEPLOYMENTS[@]}"; do
    DEP="${DEPLOYMENTS[$i]}"

    # Round-robin index: if we have more deployments than nodes → wrap around
    NODE_INDEX=$(( i % ${#WORKER_NODES[@]} ))
    NODE="${WORKER_NODES[$NODE_INDEX]}"

    echo "Patching deployment/$DEP → nodeName=$NODE"

    # Pin deployment with nodeName
    oc patch deployment "$DEP" -p "{\"spec\":{\"template\":{\"spec\":{\"nodeName\":\"$NODE\"}}}}"
done

info "Done! 4 deployments are now hard-pinned, one node each (with rollover)."