def update_event(batch_id,descriptions,descriptor,value)
  descriptions.each do |description|
    events = LabEvent.where(batch_id: batch_id, eventful_type: 'Request') 
    raise "Unable to find events for batch_id #{batch_id}" if events.empty?
    labs = events.where(description: description) 
    raise "Unable to find events for description #{description}" if labs.empty?
    labs.each do |lab|
      if lab[:descriptor_fields].include?(descriptor)
        lab[:descriptors][descriptor] = value
        lab.save!
      else
        raise "Unable to find #{descriptor} in descriptor_fields :: #{lab[:descriptor_fields]}"
      end
    end
  end; nil
  # rebroadcast
  batch = Batch.find batch_id
  batch.touch
end


# update_event(b.id,'Cluster Generation','Chip Barcode','HTNKVCCXY')
# update_event(xxxxx,'Cluster Generation','Cartridge barcode','XXXXXXX-050V2')
# LabEvent.where(batch_id: batch_id).where(description: descriptions).map {|e| e[:descriptors].delete("Chip barcode"); e.save!}
# descriptions = ['Loading','Read 1 & 2']; descriptor = 'SBS cartridge'; value = '20349317'
# descriptions.each {|description| puts description; update_event(batch_id,description,descriptor,value)}

# data_hash = {
#   'Buffer cartridge' => '20348457',
#   'Cluster cartridge' => '20348542',
#   'SBS cartridge' => '20351654'
# }
# data_hash.each do |k,v|
#   update_event(74136,descriptions,k,v)
# end

# data_hash = {
#   'Chip barcode' => 'CLV3J',
#   'Cartridge barcode' => 'MS8703801-050V2',
#   'Operator' => 'mq1',
#   'Machine name' => 'MS5'}
#
# Lane loading concentration (pM)

# data = {
#   'Operator' => 'kl',
#   'Pipette Carousel' => '8',
#   'Kit library tube' => 'NV0149587-LIB',
#   'Buffer cartridge' => '20391542',
#   'Cluster cartridge' => '20399043',
#   'SBS cartridge' => '20397472',
#   'iPCR batch #' => '86'
# }
# data.each do |k,v|
#   update_event(73619,['Read 1 & 2'],k,v)
# end


# 'Pipette Carousel' => '',
# 'Kit library tube' => '',
# 'Buffer cartridge' => '',
# 'Cluster cartridge' => '',
# 'SBS cartridge' => '',
# 'iPCR batch #' => ''
# Comment: ''
#
# data_hash = {
#   'Pipette Carousel' => 'Sean',
#   'Kit library tube' => 'NV0094477-LIB',
#   'Buffer cartridge' => '20364819',
#   'Cluster cartridge' => '20361832',
#   'SBS cartridge' => '20362839',
#   'iPCR batch #' => '80'
# }
#

# data_hash.each do |k,v|
#   update_event(xxxxx,descriptions,k,v)
# end

# data_hash = {
#   'Chip Barcode' => 'HM2LFDSXX'
# }
#
# data_hash = {
#   'Buffer cartridge' => '20369438',
#   'Cluster cartridge' => '20376776',
#   'SBS cartridge' => '20375606',
#   'iPCR batch #' => '81'
# }
# descriptions=['Read 1 & 2']
