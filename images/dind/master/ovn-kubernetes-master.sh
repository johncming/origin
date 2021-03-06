#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

source /usr/local/bin/openshift-dind-lib.sh
source /data/dind-env

function ovn-kubernetes-master() {
  local config_dir=$1
  local kube_config="${config_dir}/admin.kubeconfig"

  token=$(cat ${config_dir}/ovn.token)

  local master_config="${config_dir}/master-config.yaml"
  cluster_cidr=$(python -c "import yaml; stream = file('${master_config}', 'r'); y = yaml.load(stream); print y['networkConfig']['clusterNetworks'][0]['cidr']")
  svc_cidr=$(python -c "import yaml; stream = file('${master_config}', 'r'); y = yaml.load(stream); print y['networkConfig']['serviceNetworkCIDR']")
  apiserver=$(awk '/server:/ { print $2; exit }' ${kube_config})
  ovn_master_ip=$(echo -n ${apiserver} | cut -d "/" -f 3 | cut -d ":" -f 1)

  echo "Enabling and start ovn-kubernetes master services"
  /usr/local/bin/ovnkube \
	--k8s-apiserver "${apiserver}" \
	--k8s-cacert "${config_dir}/ca.crt" \
	--k8s-token "${token}" \
	--cluster-subnet "${cluster_cidr}" \
	--service-cluster-ip-range "${svc_cidr}" \
	--nb-address "tcp://${ovn_master_ip}:6641" \
	--sb-address "tcp://${ovn_master_ip}:6642" \
	--init-master `hostname` \
	--net-controller \
	--nodeport
}

if [[ -n "${OPENSHIFT_OVN_KUBERNETES}" ]]; then
  ovn-kubernetes-master /data/openshift.local.config/master
fi
