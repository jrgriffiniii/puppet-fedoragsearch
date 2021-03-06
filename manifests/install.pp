
# == Class: fedoragsearch::install
#
# Class for managing the installation process of Fedora Generic Search
#
class fedoragsearch::install inherits fedoragsearch {

  package { 'ant':

    ensure => 'installed'
  }

  require '::java', 'epel', '::fedora_commons'
   
  exec { 'fedoragsearch_download':
    
    command => "/usr/bin/env wget ${fedoragsearch::download_url} -O /tmp/fedoragsearch.zip",
    unless => '/usr/bin/env stat /tmp/fedoragsearch.zip'
  }

  # @todo Resolve the redundancy here (this may be invoked twice)
  exec { 'fedoragsearch_decompress':

    command => "/usr/bin/env unzip -o /tmp/fedoragsearch.zip fedoragsearch-2.7/fedoragsearch.war -d /tmp",
    require => Exec['fedoragsearch_download']
  }

  exec { 'fedoragsearch_deploy':

    command => "/usr/bin/env cp /tmp/fedoragsearch-2.7/fedoragsearch.war ${fedoragsearch::servlet_webapps_dir_path}",
    require => [ Class['::fedora_commons'], Exec['fedoragsearch_decompress'] ]
  }
  
  file { "${fedoragsearch::fedora_home}/server/config/fedora-users.xml":

    content => template('fedoragsearch/fedora-users.xml.erb'),
    require => Class['::fedora_commons']
  }

  exec { 'fedoragsearch_ant_update_build':
    
    command => "/usr/bin/env sed -i 's#property file=\"fgsconfig-basic.properties#property file=\"fgsconfig-basic-for-islandora.properties#' ${fedoragsearch::servlet_webapps_dir_path}/fedoragsearch/FgsConfig/fgsconfig-basic.xml",
    unless => "/usr/bin/env grep -q 'for-islandora' ${fedoragsearch::servlet_webapps_dir_path}/fedoragsearch/FgsConfig/fgsconfig-basic.xml",
    tries => 10,
    try_sleep => 3,
    require => Exec['fedoragsearch_deploy']
  }

  exec { 'fedoragsearch_ant_build':
    
    command => "/usr/bin/env ant -f fgsconfig-basic.xml",
    unless => "/usr/bin/env stat ${fedoragsearch::servlet_webapps_dir_path}/fedoragsearch/FgsConfig/configForIslandora/fgsconfigFinal/index/FgsIndex/conf/schema-${fedoragsearch::solr_version}-for-fgs-${fedoragsearch::version}.xml",
    cwd => "${fedoragsearch::servlet_webapps_dir_path}/fedoragsearch/FgsConfig",
    require => [ Package['ant'], Exec['fedoragsearch_ant_update_build'] ]
  }

  exec { 'fedoragsearch_solr_schema_deploy':

    command => "/usr/bin/env cp ${fedoragsearch::servlet_webapps_dir_path}/fedoragsearch/FgsConfig/configForIslandora/fgsconfigFinal/index/FgsIndex/conf/schema-${fedoragsearch::solr_version}-for-fgs-${fedoragsearch::version}.xml ${fedoragsearch::install_dir_path}/${fedoragsearch::solr_index_name}/conf/schema.xml",
    require => Exec['fedoragsearch_ant_build']
  }
}
