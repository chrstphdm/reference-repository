site :nancy do |site_uid|
  3.times do |i|
    pdu "graphene-pdu#{i+7}" do |pdu_uid|
      vendor "Eaton Corporation"
      model ""
      sensors [
        {
          :power => {
            :per_outlets => true,
            :snmp => {
              :available => true,
              :total_oids => ["iso.3.6.1.4.1.534.6.6.7.5.5.1.3.0.1", "iso.3.6.1.4.1.534.6.6.7.5.5.1.3.0.2"],
              :unit => "W",
              :outlet_prefix_oid => "iso.3.6.1.4.1.534.6.6.7.6.5.1.3.0"
            }
          }
        }
      ]
    end
  end
  6.times do |i|
    pdu "graphene-pdu#{i+1}" do |pdu_uid|
      vendor "APC"
      model "AP7953"
      sensors [
        {
          :power => {
            :per_outlets => false,
            :snmp => {
              :available => true,
              :total_oids => ["iso.3.6.1.4.1.318.1.1.12.1.16.0"],
              :unit => "W"
            }
          }
        }
      ]
    end
  end
  6.times do |i|
    pdu "griffon-pdu#{i+1}" do |pdu_uid|
      vendor "APC"
      model "AP7953"
      sensors [
        {
          :power => {
            :per_outlets => false,
            :snmp => {
              :available => true,
              :total_oids => ["iso.3.6.1.4.1.318.1.1.12.1.16.0"],
              :unit => "W"
            }
          }
        }
      ]
    end
  end
end
