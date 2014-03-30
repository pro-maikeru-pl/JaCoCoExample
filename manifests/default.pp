# =============== Java

package { "oracle-java7-installer":
  ensure => present,
}

package { "oracle-java7-set-default":
  ensure => present,
  require => Package["oracle-java7-installer"],
}

# ========= required tools

package { "htop":
  ensure => present,

}

package { "maven":
  ensure => present,
  require => Package["oracle-java7-installer", "oracle-java7-set-default"],
}


package { "zip":
  ensure => present,

}


package { "git":
  ensure => present,

}


package { "language-pack-pl":
  ensure => present,

}

package { "mc":
  ensure => present,

}

# ========= MySQL

exec { "mysqlRootPassword":
  command => "echo 'mysql-server mysql-server/root_password password vagrant' | debconf-set-selections && echo 'mysql-server mysql-server/root_password_again password vagrant' | debconf-set-selections",
  path => ["/bin/", "/usr/bin"],
  unless => "dpkg -l | grep -cq mysql-server"
}

package { "mysql-server":
  ensure => present,
  require => Exec["mysqlRootPassword"],
}


package { "mysql-client":
  ensure => present,

}

