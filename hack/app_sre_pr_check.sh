#!/bin/bash

set -exv

trap "rm -f sorted-before*.yaml.tmpl sorted-after*.yaml.tmpl" EXIT

# all custom alerts must have a namespace label
MISSING_NS="false"
for F in $(find ./deploy/sre-prometheus -type f -iname '*prometheusrule.yaml')
do
    # requires yq
    MISSING_NS_COUNT=$(cat $F | python -c 'import json, sys, yaml ; y=yaml.safe_load(sys.stdin.read()) ; print(json.dumps(y))' | jq -r '.spec.groups[].rules[] | select(.alert != null) | select(.namespace == null) and select(.labels.namespace == null)' | wc -l)

    if [ "$MISSING_NS_COUNT" != "0" ]
    then
        echo "ERROR: Rule missing 'namespace' in file '$F'"
        MISSING_NS="true"
    fi
done

if [ "$MISSING_NS" == "true" ]
then
    echo "ERROR: one or more files missing 'namespace' label, see 'ERROR' output in above logs"
    exit 2
fi

# if running `make` changes anything, fail the build
# order is inconsistent across systems, sort the template file.. it's not perfect but it's better than nothing
for environment in interation stage production;
do
    cat hack/00-osd-managed-cluster-config-${env}.yaml.tmpl | sort > sorted-before-${env}.yaml.tmpl
done

make

for environment in interation stage production;
do
    cat hack/00-osd-managed-cluster-config-${env}.yaml.tmpl | sort > sorted-after-${env}.yaml.tmpl
    diff sorted-before-${env}.yaml.tmpl sorted-after-${env}.yaml.tmpl || (echo "Running 'make' caused changes.  Run 'make' and commit changes to the PR to try again." && exit 1)
done

# script needs to pass for app-sre workflow 
exit 0
