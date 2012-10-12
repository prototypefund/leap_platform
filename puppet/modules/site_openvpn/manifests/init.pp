class site_openvpn {
  package {
    'openvpn':
      ensure => installed;
  }
  service {
    'openvpn':
      ensure     => running,
      hasrestart => true,
      hasstatus  => true,
      require    => Exec['concat_/etc/default/openvpn'];
  }

  file {
    '/etc/openvpn':
      ensure  => directory,
      require => Package['openvpn'];
  }

  file {
    '/etc/openvpn/keys':
      ensure  => directory,
      require => Package['openvpn'];
  }

  concat {
    '/etc/default/openvpn':
      owner  => root,
      group  => root,
      mode   => 644,
      warn   => true,
      notify => Service['openvpn'];
  }

  concat::fragment {
    'openvpn.default.header':
      content => template('openvpn/etc-default-openvpn.erb'),
      target  => '/etc/default/openvpn',
      order   => 01;
  }

  concat::fragment {
    "openvpn.default.autostart.${name}":
      content => 'AUTOSTART=all',
      target  => '/etc/default/openvpn',
      order   => 10;
  }
}
