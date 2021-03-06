# MDM configuration
# requires FACTER ::mdm_ips to be set if not run from master MDM

define scaleio::mdm (
  $sio_name,                            # string - MDM name
  $ensure                 = 'present',  # present|absent - Install or remove standby MDM in cluster
  $ensure_properties      = 'present',  # present|absent - Change or remove properties in MDM
  $role                   = 'manager',  # 'manager'|'tb' - Specify role of the MDM when adding to cluster
  $port                   = undef,      # int - Specify port when adding to cluster
  $ips                    = undef,      # string - Specify IPs when adding to cluster
  $management_ips         = undef,      # string - Specify management IPs for cluster or change later
  )
{
  if $ensure == 'present' {
    $management_ip_opts = $management_ips ? {undef => '', default => "--new_mdm_management_ip ${management_ips}" }
    $port_opts = $port ? {undef => '', default => "--new_mdm_port ${port}" }
    $ip = $ips.split(",")[0]
    exec { "ping_check_${ip}":
      command => "while true; do ping -c 1 ${ip} > /dev/null 2>&1 ;  if [[ $? -eq 0 ]]; then break ; fi; done",
      timeout => 1800,
      path    => "/bin:/usr/bin",
      provider => "shell"
    }
    scaleio::cmd {"MDM ${title} ${ensure}":
      action       => 'add_standby_mdm',
      ref          => 'new_mdm_name',
      value        => $sio_name,
      scope_ref    => 'mdm_role',
      scope_value  => $role,
      extra_opts   => "--new_mdm_ip ${ips} ${port_opts} ${management_ip_opts} --force_clean --i_am_sure",
      unless_query => 'query_cluster | grep',
      require      => "Exec[ping_check_${ip}]"
    }
  }
  elsif $ensure == 'absent' {
    scaleio::cmd {"MDM ${title} ${ensure}":
      action       => 'remove_standby_mdm',
      ref          => 'remove_mdm_name',
      value        => $sio_name,
      onlyif_query => 'query_cluster | grep'
    }
  }

  if $management_ips {
    scaleio::cmd {"properties ${title} ${ensure_properties}":
      action       => 'modify_management_ip',
      ref          => 'target_mdm_name',
      value        => $sio_name,
      extra_opts   => "--new_mdm_management_ip ${management_ips}",
      unless_query => "query_cluster | grep -B 1 \"Management IPs: ${management_ips}\" | grep",
      require      => Scaleio::Cmd["MDM ${title} ${ensure}"]
    }
  }

  # TODO:
  # allow_asymmetric_ips, allow_duplicate_management_ips
}
