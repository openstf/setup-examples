# -*- mode: ruby -*-
# -*- coding: utf-8 -*-

# Defaults for config options defined in CONFIG
$num_instances = 3
$instance_name_prefix = 'core'
$update_channel = 'alpha'
$image_version = 'current'
$vm_memory = 512
$vm_cpus = 1
$shared_folders = {}
$forwarded_ports = {}

# Used to fetch a new discovery token for a cluster of size $num_instances
$new_discovery_url="https://discovery.etcd.io/new?size=#{ $num_instances }"

# Automatically replace the discovery token on 'vagrant up'

if File.exists?('user-data') && (ARGV[0].eql?('up') || ARGV[0].eql?('reload'))
  require 'open-uri'
  require 'yaml'

  token = open($new_discovery_url).read

  data = YAML.load(IO.readlines('user-data')[1..-1].join)

  if data.key? 'coreos' and data['coreos'].key? 'etcd2'
    data['coreos']['etcd2']['discovery'] = token
  end

  # Fix for YAML.load() converting reboot-strategy from 'off' to `false`
  if data.key? 'coreos' and data['coreos'].key? 'update' and data['coreos']['update'].key? 'reboot-strategy'
    if data['coreos']['update']['reboot-strategy'] == false
      data['coreos']['update']['reboot-strategy'] = 'off'
    end
  end

  yaml = YAML.dump(data)
  File.open('user-data', 'w') { |file| file.write("#cloud-config\n\n#{yaml}") }
end
