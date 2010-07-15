site :toulouse do |site_uid|
  name "Toulouse"
  location "Toulouse, France"
  web
  description ""
  latitude 43.6167
  longitude 1.4333
  email_contact
  sys_admin_contact
  security_contact
  user_support_contact
  ( %w{sid-x64-base-1.0 sid-x64-base-1.1 sid-x64-nfs-1.0 sid-x64-nfs-1.1 sid-x64-big-1.1} + 
    %w{etch-x64-base-1.0 etch-x64-base-1.1 etch-x64-nfs-1.0 etch-x64-nfs-1.1 etch-x64-big-1.0 etch-x64-big-1.1} +
    %w{lenny-x64-base-0.9 lenny-x64-nfs-0.9 lenny-x64-big-0.9 lenny-x64-base-1.0 lenny-x64-nfs-1.0 lenny-x64-big-1.0}  ).each{|env_uid| environment env_uid, :refer_to => "grid5000/environments/#{env_uid}"}

  cluster :violette do |cluster_uid|
    model "Sun Fire V20z"
    created_at Time.parse("2004-09-01").httpdate
    
    52.times do |i|
      node "#{cluster_uid}-#{i+1}" do |node_uid|
        if i == 0
          supported_job_types({:deploy => false, :besteffort => true, :virtual => false})
        else
          supported_job_types({:deploy => true, :besteffort => true, :virtual => false})
        end
        architecture({
          :smp_size => 2, 
          :smt_size => 2,
          :platform_type => "x86_64"
          })
        processor({
          :vendor => "AMD",
          :model => "AMD Opteron",
          :version => "248",
          :clock_speed => 2190.M,
          :instruction_set => "",
          :other_description => "",
          :cache_l1 => nil,
          :cache_l1i => nil,
          :cache_l1d => nil,
          :cache_l2 => nil
        })
        main_memory({
          :ram_size => 2.GiB, # bytes
          :virtual_size => nil
        })
        operating_system({
          :name => nil,
          :release => nil,
          :version => nil
        })
        storage_devices [
          {:interface => 'SCSI', :size => 73.GB, :driver => "mptspi"}
          ]
        network_adapters [
          { :interface => 'Ethernet', :rate => 1.G,
            :vendor => "Broadcom", :version => "BCM5703X", :driver => "tg3",
            :enabled => true, :switch => "cict-switch", :mountable => true, :mounted => true,
            :network_address => "#{node_uid}.#{site_uid}.grid5000.fr",
            :ip => dns_lookup("#{node_uid}.#{site_uid}.grid5000.fr"),
            :mac => lookup('toulouse-violette', node_uid, 'mac_eth0')},
          { :interface => 'Ethernet', :rate => 1.G,
            :vendor => "Broadcom", :version => "BCM5703X", :driver => "tg3",
            :enabled => false, :switch => nil,
            :mac => lookup('toulouse-violette', node_uid, 'mac_eth1')},
          { :interface => 'IPMI', :rate => 1.G,
            :enabled => true, :switch => 'cict-switch', :mountable => false, :mounted => false,
            :network_address => "sp0"+`printf "%.2d" #{i+3}`+".gridmip.cict.fr",
            :ip => lookup('toulouse-violette', node_uid, 'ip_ipmi'),
            :mac => lookup('toulouse-violette', node_uid, 'mac_ipmi')}
          ]  
      end      
    end
  end
  
  cluster :pastel do |cluster_uid|
    model "Sun Fire X2200 M2"
    created_at Time.parse("2007-11-29").httpdate
    
    80.times do |i|
      node "#{cluster_uid}-#{i+1}" do |node_uid|
        supported_job_types({:deploy => true, :besteffort => true, :virtual => "amd-v"})
        architecture({
          :smp_size => 2, 
          :smt_size => 4,
          :platform_type => "x86_64"
          })
        processor({
          :vendor => "AMD",
          :model => "AMD Opteron",
          :version => "2218",
          :clock_speed => 2613.M,
          :instruction_set => "",
          :other_description => "",
          :cache_l1 => nil,
          :cache_l1i => nil,
          :cache_l1d => nil,
          :cache_l2 => 1.MiB
        })
        main_memory({
          :ram_size => 8.GiB, # bytes
          :virtual_size => nil
        })
        operating_system({
          :name => nil,
          :release => nil,
          :version => nil
        })
        storage_devices [
          {:interface => 'SATA', :size => 250.GB, :driver => "sata_nv"}
          ]
        network_adapters [
          { :interface => 'Ethernet', :rate => 1.G,
            :vendor => "NVIDIA", :version => "MCP55 Pro", :driver => "forcedeth",
            :enabled => true, :switch => "r4", :mountable => true, :mounted => true,
            :network_address => "#{node_uid}.#{site_uid}.grid5000.fr",
            :ip => dns_lookup("#{node_uid}.#{site_uid}.grid5000.fr"),
            :mac => lookup('toulouse-pastel', node_uid, 'mac_eth0')},
          { :interface => 'Ethernet', :rate => 1.G,
            :vendor => "NVIDIA", :version => "MCP55 Pro", :driver => "forcedeth",
            :enabled => false, :switch => nil,
            :mac => lookup('toulouse-pastel', node_uid, 'mac_eth1')},
          { :interface => 'Ethernet', :rate => 1.G,
            :vendor => "Broadcom", :version => "BCM5715c", :driver => "tg3",
            :enabled => true, :switch => '<unknown>', :mountable => false, :mounted => false,
            :network_address => "pas#{i+1}.gridmip.cict.fr",
            :ip => lookup('toulouse-pastel', node_uid, 'ip_ipmi'),
            :mac => lookup('toulouse-pastel', node_uid, 'mac_ipmi')}
          ]  
      end      
    end
  end
  
end
