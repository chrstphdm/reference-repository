site :lille do |site_uid|

  cluster :chinqchint do |cluster_uid|
    model "Altix Xe 310"
    created_at nil
    kavlan true

    46.times do |i|
      node "#{cluster_uid}-#{i+1}" do |node_uid|

        performance({
        :core_flops => 8695000000,
        :node_flops => 52250000000
      })

        supported_job_types({
          :deploy       => true,
          :besteffort   => true,
          :virtual      => lookup('chinqchint', node_uid, 'supported_job_types', 'virtual')
        })

        architecture({
          :smp_size       => lookup('chinqchint', node_uid, 'architecture', 'smp_size'),
          :smt_size       => lookup('chinqchint', node_uid, 'architecture', 'smt_size'),
          :platform_type  => lookup('chinqchint', node_uid, 'architecture', 'platform_type')
        })

        processor({
          :vendor             => lookup('chinqchint', node_uid, 'processor', 'vendor'),
          :model              => lookup('chinqchint', node_uid, 'processor', 'model'),
          :version            => lookup('chinqchint', node_uid, 'processor', 'version'),
          :clock_speed        => lookup('chinqchint', node_uid, 'processor', 'clock_speed'),
          :instruction_set    => lookup('chinqchint', node_uid, 'processor', 'instruction_set'),
          :other_description  => lookup('chinqchint', node_uid, 'processor', 'other_description'),
          :cache_l1           => lookup('chinqchint', node_uid, 'processor', 'cache_l1'),
          :cache_l1i          => lookup('chinqchint', node_uid, 'processor', 'cache_l1i'),
          :cache_l1d          => lookup('chinqchint', node_uid, 'processor', 'cache_l1d'),
          :cache_l2           => lookup('chinqchint', node_uid, 'processor', 'cache_l2'),
          :cache_l3           => lookup('chinqchint', node_uid, 'processor', 'cache_l3')
        })

        main_memory({
          :ram_size     => lookup('chinqchint', node_uid, 'main_memory', 'ram_size'),
          :virtual_size => nil
        })

        operating_system({
          :name     => lookup('chinqchint', node_uid, 'operating_system', 'name'),
          :release  => "Squeeze",
          :version  => lookup('chinqchint', node_uid, 'operating_system', 'version'),
          :kernel   => lookup('chinqchint', node_uid, 'operating_system', 'kernel')
        })

        storage_devices [{
          :interface  => 'SATA II',
          :size       => lookup('chinqchint', node_uid, 'block_devices', 'sda', 'size'),
          :driver     => "ahci",
          :device     => lookup('chinqchint', node_uid, 'block_devices', 'sda', 'device'),
          :model      => lookup('chinqchint', node_uid, 'block_devices', 'sda', 'model'),
          :vendor     => lookup('chinqchint', node_uid, 'block_devices', 'sda', 'vendor'),
          :rev        => lookup('chinqchint', node_uid, 'block_devices', 'sda', 'rev')
        }]

        network_adapters [{
          :interface        => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'interface'),
          :rate             => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'rate'),
          :enabled          => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'enabled'),
          :management       => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'management'),
          :mountable        => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'mountable'),
          :mounted          => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'mounted'),
          :bridged          => false,
          :vendor           => 'Intel',
          :version          => '80003ES2LAN',
          :device           => "eth0",
          :driver           => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'driver'),
          :ip               => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'ip'),
          :switch           => "gw-lille",
          :mac              => lookup('chinqchint', node_uid, 'network_interfaces', 'eth0', 'mac')
        },
        {
          :interface        => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'interface'),
          :rate             => 1.G,
          :enabled          => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'enabled'),
          :management       => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'management'),
          :mountable        => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'mountable'),
          :mounted          => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'mounted'),
          :bridged          => true,
          :device           => "eth1",
          :vendor           => 'Intel',
          :version          => '80003ES2LAN',
          :network_address  => "#{node_uid}.#{site_uid}.grid5000.fr",
          :switch           => 'gw-lille',
          :switch_port      => lookup('chinqchint',"#{node_uid}",'network_interfaces', 'eth1', 'switch_port'),
          :ip               => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'ip'),
          :driver           => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'driver'),
          :mac              => lookup('chinqchint', node_uid, 'network_interfaces', 'eth1', 'mac')
        },
        {
          :interface            => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'interface'),
          :rate                 => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'rate'),
          :network_address      => "#{node_uid}-myri0.#{site_uid}.grid5000.fr",
          :ip                   => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'ip'),
          :ip6                  => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'ip6'),
          :mac                  => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'mac'),
          :vendor               => 'Myricom',
          :version              => "10G-PCIE-8A-C",
          :driver               => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'driver'),
          :enabled              => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'enabled'),
          :management           => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'management'),
          :mountable            => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'mountable'),
          :mounted              => lookup('chinqchint', node_uid, 'network_interfaces', 'myri0', 'mounted'),
          :management           => false,
          :device               => "myri0",
          :switch               => 'switch-myri'
        },
        {
          :interface            => 'Ethernet',
          :rate                 => 100.M,
          :network_address      => "#{node_uid}-ipmi.#{site_uid}.grid5000.fr",
          :ip                   => lookup('chinqchint', node_uid, 'network_interfaces', 'bmc', 'ip'),
          :mac                  => lookup('chinqchint', node_uid, 'network_interfaces', 'bmc', 'mac'),
          :enabled              => true,
          :mounted              => false,
          :mountable            => false,
          :management           => true,
          :device               => "bmc",
          :switch               => 'gw-lille'
        }]

        chassis({
          :serial       => lookup('chinqchint', node_uid, 'chassis', 'serial_number'),
          :name         => lookup('chinqchint', node_uid, 'chassis', 'product_name'),
          :manufacturer => lookup('chinqchint', node_uid, 'chassis', 'manufacturer')
        })

        bios({
          :version      => lookup('chinqchint', node_uid, 'bios', 'version'),
          :vendor       => lookup('chinqchint', node_uid, 'bios', 'vendor'),
          :release_date => lookup('chinqchint', node_uid, 'bios', 'release_date')
        })

        gpu({
          :gpu  => false
        })

        monitoring({
          :wattmeter  => false
        })

      end
    end
  end
end
