#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"

# Iterate over range of namespaces where to deploy the test flows
for i in $(seq "$FIRST" "$LAST"); do

    # Target namespace
    NAMESPACE=user$i-devspaces

    # Switch to target namespace
    oc project $NAMESPACE

    # Undeploy test flows
    oc delete deployment/m2k 
    oc delete deployment/r2k 
    oc delete deployment/k2m 
    oc delete deployment/k2r 

    echo "Flows undeployed from: $NAMESPACE"
done

oc project $NS_TEST
echo "Switched back to host namespace $NS_TEST"
info "Test deployments deleted."