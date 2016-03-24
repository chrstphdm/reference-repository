environment 'lenny-x64-big-1.0' do
  state "deprecated"
  file({:path => "/grid5000/images/lenny-x64-big-1.0.tgz", :md5 => "b2e48586472579ac2b908816175e4aa6"})
  available_on %w{}
  valid_on "Dell PE1855, Dell PE1950, HP DL140G3, HP DL145G2, IBM x3455, IBM e325, IBM e326, IBM e326m, Sun V20z, Sun X2200 M2, Sun X4100, Altix Xe 310"
  kernel "2.6.26.2"
  based_on "Debian version lenny for amd64"
  consoles [{:port => "ttyS0", :bps => 34800}]
  services ['ldap', 'nfs']
  accounts [{:login => "root", :password => "grid5000"}]
  applications "Vim, XEmacs, JED, nano, JOE, Perl, Python, Ruby".split(", ")
  x11_forwarding true
  max_open_files 8192
  tcp_bandwidth 1.G
end
