#!/bin/bash
# This script automates the NC classification and environment group setup for the VRO plugin provisioning workflow
# Run this as root on your master
# Note: this script does not randomize uuid for the classification group it creates, so it will create/replace the same group everytime instead of creating a new group
# This script assumes it is being run on a freshly installed master that is not using code manager.
#
# User configuration
#
alternate_environment=${1:-dev}
autosign_example_class=autosign_example
vro_user_class=vro_plugin_user
vro_sshd_class=vro_plugin_sshd
#
# Configuration we can detect
#
master_hostname=$(/opt/puppetlabs/bin/puppet config print certname)
key=$(/opt/puppetlabs/bin/puppet config print hostprivkey)
cert=$(/opt/puppetlabs/bin/puppet config print hostcert)
cacert=$(/opt/puppetlabs/bin/puppet config print localcacert)

all_nodes_id='00000000-0000-4000-8000-000000000000'
roles_group_id='235a97b3-949b-48e0-8e8a-000000000666'
dev_env_group_id='235a97b3-949b-48e0-8e8a-000000000888'
autosign_and_user_group_id='235a97b3-949b-48e0-8e8a-000000000999'
#
# Determine the uuids for groups that are created during PE install but with randomly generated uuids
#
find_guid()
{
  echo $(curl -s https://$master_hostname:4433/classifier-api/v1/groups --cert $cert --key $key --cacert $cacert | python -m json.tool |grep -C 2 "$1" | grep "id" | cut -d: -f2 | sed 's/[\", ]//g')
}
echo Puppet Master Setup Script
echo --------------------------
echo This script expects to be run from puppet-vro-starter_content directory. If run from a different directory, the script will fail.
echo This script also assumes it is being run on a freshly installed master that is not using code manager.
echo --------------------------

#
# Check if code manager is being used
#
curl -s -X GET \ -H "Content-Type: application/json" \
--cert   $cert \
--key    $key \
--cacert $cacert \
"https://$master_hostname:4433/classifier-api/v1/groups" | python -m json.tool | grep -q code_manager_auto_configure
if [ $? -eq 0 ]; then
  echo "ERROR: It appears that code manager is being used. This script can not continue."
  exit 1
fi

if [ -d /etc/puppetlabs/code/environments/$alternate_environment ]; then
  echo "ERROR: It appears that the \"$alternate_environment\" environment already exists. Please remove /etc/puppetlabs/code/environments/$alternate_environment or run 'sh scripts/vra_nc_setup.sh <environment_name>'"
  exit 1
fi

production_env_group_id=`find_guid "Production environment"`
echo "\"Production environment\" group uuid is $production_env_group_id"
agent_specified_env_group_id=`find_guid "Agent-specified environment"`
echo "\"Agent-specified environment\" group uuid is $agent_specified_env_group_id"
pemaster_group_id=`find_guid "PE Master"`
#
# Download starter content and create an alternate puppet environment in addition to production
#
echo 'Copying vRO starter content repo into /etc/puppetlabs/code/environments'
mkdir -p /etc/puppetlabs/code/environments/$alternate_environment
rm -rf /etc/puppetlabs/code/environments/$alternate_environment/*
cp -R * /etc/puppetlabs/code/environments/$alternate_environment
if [ ! -f /etc/puppetlabs/code/environments/$alternate_environment/modules/vro_plugin_user/manifests/init.pp ]; then
  echo "ERROR: Copy operation failed. Aborting script. Be sure to run 'bash scripts/vra_nc_setup.sh' inside the 'puppet-vro-starter_content' directory"
  exit 1
fi
# Put a copy in production
echo "Replacing production with $alternate_environment contents"
rm -rf /etc/puppetlabs/code/environments/production/
cp -R /etc/puppetlabs/code/environments/$alternate_environment /etc/puppetlabs/code/environments/production
#
# Tell the NC to refresh its cache so that the classes we just installed are available
#
echo "Refreshing NC class lists for production and $alternate_environment puppet environments"
curl -s -X POST -H "Content-Type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
https://$master_hostname:4433/classifier-api/v1/update-classes?environment=production
[ "$?" = 0 ] && echo "Successful refresh of production environment."
curl -s -X POST -H "Content-Type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
https://$master_hostname:4433/classifier-api/v1/update-classes?environment=$alternate_environment
[ "$?" = 0 ] && echo "Successful refresh of $alternate_environment environment."
#
# Create an "Autosign and vRO Plugin User" classification group to set up autosign example and vro-plugin-user
#
echo "Creating the Autosign and vRO Plugin User and sshd config group"
curl -s -X PUT -H 'Content-Type: application/json' \
  --key $key \
  --cert $cert \
  --cacert $cacert \
  -d '
  {
    "name": "Autosign and vRO Plugin User and sshd config",
    "parent": "'$all_nodes_id'",
    "rule":
      [ "and",
        [ "=",
          [ "trusted", "certname" ],
          "'$master_hostname'"
        ]
      ],
    "classes": { "'$autosign_example_class'": {}, "'$vro_user_class'": {}, "'$vro_sshd_class'": {} }
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups/$autosign_and_user_group_id | python -m json.tool
echo
#
# Create a "Roles" classification group so that the integration role groups are organized more cleanly
#
echo "Creating the Roles group"
curl -s -X PUT -H 'Content-Type: application/json' \
  --key $key \
  --cert $cert \
  --cacert $cacert \
  -d '
  {
    "name": "Roles",
        "parent": "'$all_nodes_id'",
        "classes": {}
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups/$roles_group_id | python -m json.tool
echo
#
# Create an environment group for an alternative puppet environment, e.g. dev puppet environment
#
for file in /etc/puppetlabs/code/environments/$alternate_environment/site/role/manifests/*; do
  basefilename=$(basename "$file")
  role_class="role::${basefilename%.*}"
  echo "Creating the \"$role_class\" classification group"

  curl -s -X POST -H "Content-Type: application/json" \
  --key    $key \
  --cert   $cert \
  --cacert $cacert \
  -d '
  {
    "name": "'$role_class'",
    "parent": "'$roles_group_id'",
    "environment": "'$alternate_environment'",
    "rule":
     [ "and",
       [ "=",
         [ "trusted", "extensions", "pp_role" ],
         "'$role_class'"
       ]
     ],
    "classes": { "'$role_class'": {} }
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups
done
echo
#
# Create alternate_environment environment group
#
echo "Creating the \"$alternate_environment\" environment group"
curl -s -X PUT -H "Content-Type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
-d '
{
  "name": "'$alternate_environment' environment",
  "parent": "'$production_env_group_id'",
  "environment_trumps": true,
  "environment": "'$alternate_environment'",
  "rule":
    [ "and",
      [ "=",
        [ "trusted", "extensions", "pp_environment" ],
        "'$alternate_environment'"
      ]
    ],
  "classes": {}
}' \
https://$master_hostname:4433/classifier-api/v1/groups/$dev_env_group_id | python -m json.tool
#
# Update the "Agent-specified environment" group so that pp_environment=agent-specified works as expected
#
echo "Updating \"Agent-specified environment\" group to use pp_environment in its matching rules"
curl -s -X PUT -H "Content-type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
-d '
{
  "name": "Agent-specified environment",
  "parent": "'$production_env_group_id'",
  "environment_trumps": true,
  "rule":
    [ "and",
      [ "=",
        [ "trusted", "extensions", "pp_environment" ],
        "agent-specified"
      ]
    ],
  "environment": "agent-specified",
  "classes": {}
}' \
https://$master_hostname:4433/classifier-api/v1/groups/$agent_specified_env_group_id | python -m json.tool
echo