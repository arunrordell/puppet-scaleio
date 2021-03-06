# Configure ScaleIO SDS and ScaleIO XCache (rfcache) services installation
include firewall

define scaleio::sds_server (
  $ensure  = 'present',  # present|absent - Install or remove SDS service
  $xcache  = 'present',  # present|absent - Install or remove XCache service
  $lia     = 'present',  # present|absent - Install or remove lia service
  $sdr     = 'absent',  # present|absent - Install or remove sdr service
  $ftp     = 'default',  # string - 'default' or FTP with user and password for driver_sync
  $pkg_ftp = undef,      # string - URL where packages are placed (for example: ftp://ftp.emc.com/Ubuntu/2.0.10000.2072)
  $pkg_path = undef,
  $password = undef,      # string - ScaleIO Password
  $cmd_provider = undef   # string - ScaleIO password decryption provider
  )
{
  firewall { '001 Open Port 7072 for ScaleIO SDS':
    dport  => [7072],
    proto  => tcp,
    action => accept,
  }
  $noop_devs = '`lsblk -d -o ROTA,KNAME | awk "/^ *0/ {print($2)}"`'
  $noop_set_cmd = 'if [ -f /sys/block/$i/queue/scheduler ]; then echo noop > /sys/block/$i/queue/scheduler; fi'

  scaleio::common_server { 'install common packages for SDS': } ->
  scaleio::package { 'sds':
    ensure  => $ensure,
    pkg_ftp => $pkg_ftp,
    pkg_path => $pkg_path
  } ->
  exec { 'Apply noop IO scheduler for SSD/flash disks':
    command => "bash -c 'for i in ${noop_devs} ; do ${noop_set_cmd} ; done'",
    path    => '/bin:/usr/bin',
  } ->
  file { 'Ensure noop IO scheduler persistent':
    content => 'ACTION=="add|change", KERNEL=="[a-z]*", ATTR{queue/rotational}=="0",ATTR{queue/scheduler}="noop"',
    path    => '/etc/udev/rules.d/60-scaleio-ssd-scheduler.rules',
  } ->

  scaleio::package { 'lia':
    ensure  => $ensure,
    pkg_ftp => $pkg_ftp,
    pkg_path => $pkg_path,
    password => $password,
    cmd_provider => $cmd_provider
  }
  scaleio::package { 'xcache':
    ensure  => $xcache,
    pkg_ftp => $pkg_ftp,
    pkg_path => $pkg_path,
    require => Scaleio::Common_server['install common packages for SDS']
  }

  if $sdr == 'present' {
    scaleio::package { 'sdr':
      ensure  => $ensure,
      pkg_ftp => $pkg_ftp,
      pkg_path => $pkg_path,
      require   => Scaleio::Package['sds']
    }

    service { 'sdr':
      ensure    => 'running',
      enable    => true,
      hasstatus => true,
      require   => Scaleio::Package['sdr'],
      provider  => $provider
    }
  }

  if $xcache == 'present' {
    service { 'xcache':
      ensure => 'running',
      require => "Scaleio::Package[xcache]"
    }
  }

  if $lia == 'present' {
    service { 'lia':
      ensure    => 'running',
      enable    => true,
      hasstatus => true,
      require   => Scaleio::Package['lia'],
      provider  => $provider
    }
  }

  # TODO:
  # "absent" cleanup
}
