environment 'lenny-x64-big-2.6' do
  state "deprecated"
  file({:path => "/grid5000/images/lenny-x64-big-2.6.tgz", :md5 => "2387f5ad1d9c0d5b539fae80715841e0"})
  kernel "2.6.26.2"
  available_on %w{}
  valid_on "bordeplage , bordereau , borderline ,  adonis , edel , genepi , chicon , chimint , chinqchint , chirloute , granduc , capricorne , sagittaire , graphene , griffon , stremi , paramount , parapide , parapluie , helios , sol , suno, pastel"
  based_on "Debian version lenny for amd64"
  consoles [{:port => "ttyS0", :bps => 34800}]
  services []
  accounts [{:login => "root", :password => "grid5000"}]
  applications "Vim, XEmacs, JED, nano, JOE, Perl, Python, Ruby".split(", ")
  x11_forwarding true
  max_open_files 8192
  tcp_bandwidth 1.G
end
