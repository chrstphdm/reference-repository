site :nancy do |site_uid|

  cluster :griffon do |cluster_uid|
    model "Carri System CS-5393B"
    created_at Time.parse("2009-04-10").httpdate
    kavlan true
    92.times do |i|
      node "#{cluster_uid}-#{i+1}" do |node_uid|
        serial lookup('griffon', node_uid, 'chassis', 'serial_number')
        supported_job_types({:deploy => true, :besteffort => true, :virtual => "ivt"})
        performance({
          :node_flops => 7.963,
          :core_flops => 52.5
        })
        architecture({
          :smp_size => 2,
          :smt_size => 8,
          :platform_type => "x86_64"
          })
        processor({
          :vendor => "Intel",
          :model => "Intel Xeon",
          :version => "L5420",
          :clock_speed => 2.5.G,
          :instruction_set => "",
          :other_description => "",
          :cache_l1 => nil,
          :cache_l1i => nil,
          :cache_l1d => nil,
          :cache_l2 => 12.MiB
        })
        main_memory({
          :ram_size => 16.GiB,
          :virtual_size => nil
        })
        operating_system({
          :name => "Debian",
          :release => "6.0",
          :version => nil,
	  :kernel => "2.6.32"
        })
        storage_devices [{
          :interface => 'SATA II',
          :size => 320.GB,
          :driver => "ahci",
	  :device => "sda",
	  :model => lookup('griffon', node_uid, 'block_devices', 'sda', 'model'),
	  :rev => lookup('griffon', node_uid, 'block_devices', 'sda', 'rev')
        }]
        network_adapters [{
          :interface => 'Ethernet',
          :rate => 1.G,
          :device => "eth0",
          :enabled => true,
          :mounted => true,
          :mountable => true,
          :bridged => true,
          :management => false,
          :switch => lookup('griffon', node_uid, 'network_interfaces', 'eth0', 'switch_name'),
          :switch_port => lookup('griffon', node_uid, 'network_interfaces', 'eth0', 'switch_port'),
          :mac => lookup('griffon', node_uid, 'network_interfaces', 'eth0', 'mac'),
          :ip => lookup('griffon', node_uid, 'network_interfaces', 'eth0', 'ip'),
          :network_address => "#{node_uid}.#{site_uid}.grid5000.fr",
          :driver => "e1000e",
	  :vendor => "intel",
	  :version => "80003ES2LAN"
        },
        {
          :interface => 'Ethernet',
          :rate => 1.G,
          :enabled => false,
          #:mounted => false,
          :mac => lookup('griffon', node_uid, 'network_interfaces', 'eth1', 'mac'),
          #:mountable => false,
          #:management => false,
          #:driver => "e1000e",
	  :vendor => "intel",
	  :version => "BCM5721"
        },
	{
          :interface => 'InfiniBand',
          :rate => 20.G,
          :device => "ib0",
          :enabled => true,
          :mounted => true,
          :mountable => true,
          :management => false,
          :network_address => "#{node_uid}-ib0.#{site_uid}.grid5000.fr",
          :ip => lookup('griffon', node_uid, 'network_interfaces', 'ib0', 'ip'),
          :guid => lookup('griffon', node_uid, 'network_interfaces', 'ib0', 'guid'),
          :hwid => lookup('griffon', node_uid, 'network_interfaces', 'ib0', 'hwid'),
	  :switch => "sgriffonib",
          :ib_switch_card => lookup('griffon', node_uid, 'network_interfaces', 'ib0', 'line_card'),
          :ib_switch_card_pos => lookup('griffon', node_uid, 'network_interfaces', 'ib0', 'position'),
          :driver => "mlx4_core", :vendor => "Mellanox", :version => "MT26418"
        },
        {
          :interface => 'InfiniBand',
          :rate => 20.G,
          :enabled => false,
          #:mountable => false,
          #:mounted => false,
          #:management => false,
          :vendor => "Mellanox",
	  :version => "MT26418",
          :guid => lookup('griffon', node_uid, 'network_interfaces', 'ib1', 'guid'),
        },
        {
          :interface => 'Ethernet',
          :rate => 100.M,
          :enabled => true,
          :mounted => false,
          :mountable => false,
          :management => true,
          :vendor => "Tyan", :version => "M3296",
          :network_address => "#{node_uid}-ipmi.#{site_uid}.grid5000.fr",
          :ip => lookup('griffon', node_uid, 'network_interfaces', 'bmc', 'ip'),
          :mac => lookup('griffon', node_uid, 'network_interfaces', 'bmc', 'mac'),
          :switch => lookup('griffon', node_uid, 'network_interfaces', 'bmc', 'switch_name'),
          :switch_port => lookup('griffon', node_uid, 'network_interfaces', 'bmc', 'switch_port')
        }]
	# pdu({
	#   :vendor => "American Power Conversion",
  #        :pdu => lookup('griffon', node_uid, 'pdu', 'pdu_name'),
  #        :pdu_port => lookup('griffon', node_uid, 'pdu', 'pdu_position'),
	# })

  bios({
	  :version	=> lookup('griffon', node_uid, 'bios', 'version'),
	  :vendor	=> lookup('griffon', node_uid, 'bios', 'vendor'),
	  :release_date	=> lookup('griffon', node_uid, 'bios', 'release_date'),
	})
    gpu({
       :gpu  => false
        })

    sensors({
      :power => {
        :available => false, # Set to true when pdu resources will be declared
        :via => {
          :pdu => { :uid => lookup('griffon', node_uid, 'pdu', 'pdu_name') }
        }
      }
    })
      end
    end
  end # cluster griffon
end # nancy
