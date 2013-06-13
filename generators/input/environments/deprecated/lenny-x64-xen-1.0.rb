environment 'lenny-x64-xen-1.0' do
  state "testing"
  file({:path => "/grid5000/images/lenny-x64-xen-1.0.tgz", :md5 => "3e292c686c3ed0b417e44fdde5ec1771"})
  available_on %w{}
  valid_on "Dell PE1855, Dell PE1950, HP DL140G3, HP DL145G2, IBM x3455, IBM e325, IBM e326, IBM e326m, Sun V20z, Sun X2200 M2, Sun X4100, Altix Xe 310"
  kernel "2.6.26-2-xen-amd64"
  based_on "Debian version etch for amd64"
  consoles [{:port => "ttyS0", :bps => 34800}]
  services []
  accounts [{:login => "root", :password => "grid5000"}]
  applications "Vim, XEmacs, JED, nano, JOE, Perl, Python, Ruby".split(", ")
  x11_forwarding true
  max_open_files 8192
  tcp_bandwidth 1.G
end
