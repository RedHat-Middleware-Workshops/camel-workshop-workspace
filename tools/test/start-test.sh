#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"

# Change directory where deployment definitions are defined
cd /projects/workshop/tools/test/deployments

# Ensure we start working from hosting namespace
oc project $NS_TEST

# Retrieve all images ids
IMAGE_M2K=$(oc get deployment m2k -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "M2K image: $IMAGE_M2K"

IMAGE_K2R=$(oc get deployment k2r -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "K2R image: $IMAGE_K2R"

IMAGE_R2K=$(oc get deployment r2k -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "M2K image: $IMAGE_R2K"

IMAGE_K2M=$(oc get deployment k2m -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "K2R image: $IMAGE_K2M"

# Iterate over range of namespaces where to deploy the test flows
for i in $(seq "$FIRST" "$LAST"); do

    # Target namespace
    NAMESPACE=user$i-devspaces

    echo "deploying in $NAMESPACE"

    oc project $NAMESPACE

    # Deploy Matrix to Kafka
    oc apply -f m2k.yaml
    oc set image deployment/m2k m2k=$IMAGE_M2K
    oc scale deployment/m2k --replicas=1

    # Deploy Kafka to RocketChat
    oc apply -f k2r.yaml
    oc set image deployment/k2r k2r=$IMAGE_K2R
    oc set env deployment/k2r RC_ROOM=$TEST_ROOM
    oc scale deployment/k2r --replicas=1

    # Deploy RocketChat to Kafka
    oc apply -f r2k.yaml
    oc set image deployment/r2k r2k=$IMAGE_R2K 
    oc scale deployment/r2k --replicas=1

    # Deploy Kafka to Matrix
    oc apply -f k2m.yaml
    oc set image deployment/k2m k2m=$IMAGE_K2M 
    oc scale deployment/k2m --replicas=1

    echo "Done deployment in $NAMESPACE"
done

oc project $NS_TEST

echo "Switched back to host namespace $NS_TEST"


