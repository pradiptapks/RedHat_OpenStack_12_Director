#!/bin/bash

set -ux


### --start_docs
## Deploying the overcloud with Opendaylight integration
## =======================

## Prepare Your Environment with 3 controller and 2 compute nodes.
## ------------------------

## * Source in the undercloud credentials.
## ::

source /home/stack/stackrc

{% if hypervisor_wait|bool %}
### --stop_docs
# Wait until there are hypervisors available.
while true; do
    count=$(openstack hypervisor stats show -c count -f value)
    if [ $count -gt 0 ]; then
        break
    fi
done
{% endif %}

time openstack overcloud deploy \
 --templates /usr/share/openstack-tripleo-heat-templates/ \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
 -e /home/stack/osp_deploy/opendaylight/network-environment.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-opendaylight.yaml \
 -e /home/stack/osp_deploy/opendaylight/docker_local_images.yaml \
 -e /home/stack/osp_deploy/opendaylight/odl_local_images.yaml \
 --control-flavor control --control-scale 3 \
 --compute-flavor compute --compute-scale 2 \
 --validation-warnings-fatal \
 --libvirt-type qemu --ntp-server clock.redhat.com --timeout 90


# Check if the deployment has started. If not, exit gracefully. If yes, check for errors.
if ! openstack stack list | grep -q overcloud; then
    echo "overcloud deployment not started. Check the deploy configurations"
    exit 1

    # We don't always get a useful error code from the openstack deploy command,
    # so check `openstack stack list` for a CREATE_COMPLETE or an UPDATE_COMPLETE
    # status.
elif ! openstack stack list | grep -Eq '(CREATE|UPDATE)_COMPLETE'; then
        # get the failures list
    openstack stack failures list overcloud --long > /home/stack/failed_deployment_list.log || true

    # get any puppet related errors
    for failed in $(openstack stack resource list --nested-depth 5 overcloud | grep FAILED | grep 'StructuredDeployment ' | cut -d '|' -f3)
    do
    echo "heat deployment-show output for deployment: $failed" >> /home/stack/failed_deployments.log
    echo "######################################################" >> /home/stack/failed_deployments.log
    heat deployment-show $failed >> /home/stack/failed_deployments.log
    echo "######################################################" >> /home/stack/failed_deployments.log
    echo "puppet standard error for deployment: $failed" >> /home/stack/failed_deployments.log
    echo "######################################################" >> /home/stack/failed_deployments.log
    # the sed part removes color codes from the text
    heat deployment-show $failed |
        jq -r .output_values.deploy_stderr |
        sed -r "s:\x1B\[[0-9;]*[mK]::g" >> /home/stack/failed_deployments.log
    echo "######################################################" >> /home/stack/failed_deployments.log
    # We need to exit with 1 because of the above || true
    done
    exit 1
fi
