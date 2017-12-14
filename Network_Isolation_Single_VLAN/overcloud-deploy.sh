openstack overcloud deploy \
 --templates \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
 -e /home/stack/templates/overcloud_images.yaml \
 -e /home/stack/templates/network-environment.yaml \
 --libvirt-type qemu --ntp-server clock.redhat.com --timeout 90
