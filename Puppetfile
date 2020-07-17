# This is a Puppetfile, which describes a collection of Puppet modules.
# For format and syntax examples, see:
#
# https://docs.puppet.com/pe/latest/cmgmt_puppetfile.html
#
# In addition to the component modules listed here, the 'site' directory
# includes 'role' and 'profile' modules. The 'role' module contains
# Puppet classes that constitute a machine role or business function.

forge "https://forgeapi.puppetlabs.com"

# Forge Modules from Puppet

mod 'puppetlabs-apache', '5.5.0'
mod 'puppetlabs-chocolatey', '5.0.2'
mod 'puppetlabs-mysql', '10.6.0'
mod 'puppetlabs-stdlib', '6.3.0'
mod 'puppetlabs-concat', '6.2.0'
mod 'puppetlabs-powershell', '4.4.0'
mod 'puppetlabs-registry', '3.1.0'
mod 'puppetlabs-puppetserver_gem', '1.1.1'

# Forge Community Modules

mod 'puppet-firewalld', '4.3.0'
mod 'puppet-iis', '2.0.2'
mod 'puppet-staging', '2.0.1'
mod 'puppet-windows_firewall', '1.0.3'
mod 'puppet-windowsfeature', '2.0.0'
mod 'puppet/hiera', '2.1.2'
mod 'reidmv-unzip', '0.1.2'
mod 'stahnma-epel', '1.3.0'
mod 'liamjbennett-win_facts', '0.0.2'

# Modules to prep Puppet Enterprise Master:
# You can add these to your own Puppetfile
# and classify your master with 'vra_puppet_plugin_prep'

mod 'herculesteam-augeasproviders_core', '2.1.3'
mod 'herculesteam-augeasproviders_ssh', '2.5.0'
mod 'puppetlabs-inifile', '1.6.0'
mod 'pltraining-rbac', '0.0.8'
mod 'vra_puppet_plugin_prep',
  :git => 'https://github.com/puppetlabs/puppet-vra_puppet_plugin_prep'
