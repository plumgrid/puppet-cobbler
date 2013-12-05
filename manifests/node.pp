# Definition: cobbler::node
#
# This class installs a node into the cobbler system.  Cobbler needs to be included
# in a toplevel node definition for this to be useful.
#
# Parameters:
# - $mac Mac address of the eth0 interface
# - $profile Cobbler profile to assign
# - $ip IP address to assign to eth0
# - $domain Domain name to add to the resource name
# - $preseed Cobbler/Ubuntu preseed/kickstart node name
# - $power_address = "" Power management address for the node
# - $power_type = "" 		Power management type (impitools, ucs, etc.)
# - $power_user = ""    Power management username
# - $power_password = ""  Power management password
# - $power_id = ""     Power management port-id/name
# - $boot_disk = '/dev/sda'  Default Root disk name
# - $serial = False (true for serial console)
# - $add_hosts_entry = true, Create a cobbler local hosts entry (also useful for DNS)
# - $extra_host_aliases = [] Any additional aliases to add to the host entry
#
#
define cobbler::node(
	$mac,
	$profile,
	$ip,
	$domain,
	$node_type = "",
	$preseed,
	$power_address = "",
	$power_type = "",
	$power_user = "",
	$power_password = "",
	$power_id = "",
	$boot_disk = '/dev/sda',
	$add_hosts_entry = true,
	$log_host = '',
	$extra_host_aliases = [])
{

	$preseed_file="/etc/cobbler/preseeds/$preseed"

        if($cobbler::node_gateway) {
            $gateway_opt = "netcfg/get_gateway=${cobbler::node_gateway}"
        } else {
            # There is a bug in Ubuntu's netcfg (as of 2012-09) that
            # prevents no-gateway setups working.  This is a workaround
            # - we remove the gateway in post-install.
            # (no_default_route is conveniently spare)
            $gateway_opt = "netcfg/get_gateway=${cobbler::ip} netcfg/no_default_route=true"
        }

        if($log_host) {
            $log_opt = "log_host=${log_host} BOOT_DEBUG=2"
        } else {
            $log_opt = ""
        }

        if($serial) {
            $serial_opt = "console=ttyS0,9600"
        } else {
            $serial_opt = ""
        }

	exec { "cobbler-add-node-${name}":

		command => "if cobbler system list | grep ${name};
                    then
                        action=edit;
                    else
                        action='add --netboot-enabled=true'
                    fi;
 		    cobbler system \\\${action} \
				--name='${name}' \
				--mac-address='${mac}' \
				--profile='${profile}' \
				--ip-address=${ip} \
				--dns-name='${name}.${domain}' \
				--hostname='${name}.${domain}' \
				--kickstart='${preseed_file}' \
				--kopts='netcfg/disable_autoconfig=true netcfg/dhcp_failed=true netcfg/dhcp_options=\"'\"'\"'Configure network manually'\"'\"'\" netcfg/get_nameservers=${cobbler::node_dns} netcfg/get_ipaddress=${ip} netcfg/get_netmask=${cobbler::node_netmask} ${gateway_opt} netcfg/confirm_static=true partman-auto/disk=${boot_disk} ${serial_opt} ${log_opt}' \
				--power-user=${power_user} \
				--power-address=${power_address} \
				--power-pass=${power_password} \
				--power-id=${power_id} \
				--power-type=${power_type}",
		provider => shell,
		path => "/usr/bin:/bin",
                require => [Package[cobbler],Cobbler::Ubuntu::Preseed[$preseed],Anchor["cobbler-profile-${profile}"]],
		notify => Exec["cobbler-sync"],
	}

    if ( $add_hosts_entry ) {
        host { "${name}.${domain}":
            ip => "${ip}",
            host_aliases => flatten(["${name}", $extra_host_aliases])
        }
    }
}
