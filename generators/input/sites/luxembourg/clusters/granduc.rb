site :luxembourg do |site_uid|

  cluster :granduc do |cluster_uid|
    model "PowerEdge 1950"
    created_at Time.parse("2011-12-01").httpdate

    22.times do |i|
      node "#{cluster_uid}-#{i+1}" do |node_uid|
        supported_job_types({:deploy => true, :besteffort => true, :virtual => "ivt"})
        architecture({
          :smp_size       => 2,
          :smt_size       => 8,
          :platform_type  => "x86_64"
          })
        processor({
          :vendor             => "Intel",
          :model              => "Intel Xeon",
          :version            => "L5335",
          :clock_speed        => 2.G,
          :instruction_set    => "",
          :other_description  => "",
          :cache_l1           => nil,
          :cache_l1i          => nil,
          :cache_l1d          => nil,
          :cache_l2           => nil
        })
        main_memory({
          :ram_size     => 16.GiB,
          :virtual_size => nil
        })
        operating_system({
          :name     => "Debian",
          :release  => "6.0",
          :version  => nil,
          :kernel   => "2.6.32"
        })
        storage_devices [{
          :interface  => 'SATA',
          :size       => 160.GB,
          :driver     => "mptsas",
          :device     => "sda",
          :model      => lookup('granduc', node_uid, 'block_devices', 'sda', 'model'),
          :vendor     => lookup('granduc', node_uid, 'block_devices', 'sda', 'vendor'),
          :rev        => lookup('granduc', node_uid, 'block_devices', 'sda', 'rev')
        }]
        network_adapters [{
          :interface        => 'Ethernet',
          :rate             => 1.G,
          :enabled          => true,
          :management       => true,
          :mountable        => false,
          :mounted          => false,
          :device           => "bmc",
          :network_address  => "#{node_uid}-bmc.#{site_uid}.grid5000.fr",
          :ip               => lookup('granduc', node_uid, 'network_interfaces', 'bmc', 'ip'),
          :switch           => "C6506E",
          :switch_port      => lookup('granduc', node_uid, 'network_interfaces', 'eth0', 'switch_port'),
          :mac              => lookup('granduc', node_uid, 'network_interfaces', 'bmc', 'mac')
         },
         {
          :interface        => 'Ethernet',
          :rate             => 1.G,
          :enabled          => true,
          :management       => false,
          :mountable        => true,
          :mounted          => true,
          :bridged 	        => true,
          :device           => "eth0",
          :driver           => "bnx2",
          :network_address  => "#{node_uid}.#{site_uid}.grid5000.fr",
          :ip               => lookup('granduc', node_uid, 'network_interfaces', 'eth0', 'ip'),
          :switch           => "C6506E",
          :switch_port      => lookup('granduc', node_uid, 'network_interfaces', 'eth0', 'switch_port'),
          :mac              => lookup('granduc', node_uid, 'network_interfaces', 'eth0', 'mac')
        },
        {
          :interface        => 'Ethernet',
          :rate             => 1.G,
          :enabled          => false,
          :management       => false,
          :device           => "eth1",
          :mountable        => true,
          :mounted          => false,
          :driver           => "bnx2",
          :network_address  => "#{node_uid}-eth1.#{site_uid}.grid5000.fr",
          :ip               => lookup('granduc', node_uid, 'network_interfaces', 'eth1', 'ip'),
          :switch           => "C6506E",
          :switch_port      => lookup('granduc', node_uid, 'network_interfaces', 'eth1', 'switch_port'),
          :mac              => lookup('granduc', node_uid, 'network_interfaces', 'eth1', 'mac')
        },
        {
          :interface        => 'Ethernet',
          :rate             => 10.G,
          :enabled          => true,
          :management       => false,
          :mountable        => true,
          :mounted          => true,
          :device           => "eth2",
          :driver           => "ixgbe",
          :switch           => "C5020",
          :switch_port      => lookup('granduc', node_uid, 'network_interfaces', 'eth2', 'switch_port'),
          :network_address  => "#{node_uid}-eth2.#{site_uid}.grid5000.fr",
          :ip               => lookup('granduc', node_uid, 'network_interfaces', 'eth2', 'ip'),
          :mac              => lookup('granduc', node_uid, 'network_interfaces', 'eth2', 'mac')
        }]
        bios({
           :version      => lookup('granduc', node_uid, 'bios', 'version'),
           :vendor       => lookup('granduc', node_uid, 'bios', 'vendor'),
           :release_date => lookup('granduc', node_uid, 'bios', 'release_date')
        })
        chassis({:serial_number => lookup('granduc', node_uid, 'chassis', 'serial_number')})
      end
    end
  end
end
