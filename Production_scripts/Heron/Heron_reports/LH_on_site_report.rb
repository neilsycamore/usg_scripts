def get_file(filename)
  data = CSV.read("/var/tmp/Heron_tmp/Files/#{filename}.csv")
  return data
end

def build_hash(data)
  $ap_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_hash = {'Alderley' => $ap_hash,
                 'UK Biocentre' => $mk_hash,
                 'Queen Elizabeth University Hospital' => $gla_hash,
                 'Cambridge-az' => $cb_hash
               }
  
  data.each do |centre, barcode, sample_id, result, dtime|
    # puts "#{centre},#{barcode},#{sample_id},#{result},#{dtime}"
    date = dtime.split(' ').first
    $centre_hash[centre][date] << [barcode,sample_id]
  end; nil
end

def build_negative_hash(filename)
  $ap_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_neg_hash = {'Alderley' => $ap_neg_hash,
                 'UK Biocentre' => $mk_neg_hash,
                 'Queen Elizabeth University Hospital' => $gla_neg_hash,
                 'Cambridge-az' => $cb_neg_hash
               }
  negative_plates = get_file(filename) #centre,barcode,date_tested
  negative_plates.pop # the last line of the file is centre,barcode,date_tested.. not sure why yet
  negative_plates.each do |centre,barcode,dtime|
    date = dtime.split(' ').first
    $centre_neg_hash[centre][date] << barcode
  end; nil
end

def get_week_data(week_begin)
  $centre_hash.each do |centre_name,hash|
    range = week_begin..week_begin+6
    pbc=[];sc=[] # pbc Positive Barcode Count; sc Sample Count
    hash.each do |k,values|
      if range.cover?(k.to_date)
        values.each do |b,s|
          pbc << b
          sc << s
        end
      end
    end
    ndates = []
    $centre_neg_hash[centre_name].each do |d,stuff|
      ndates << d if range.cover?(d.to_date)
    end
    if ndates.present?
      range_negative_barcodes = []
      ndates.each do |date|
        $centre_neg_hash[centre_name][date].each {|b| range_negative_barcodes << b}
      end
      nbc = range_negative_barcodes.difference(pbc.uniq).size; nil # nbc Negative Barcode Count
    else
      nbc = 'None'
    end   
    $centre_date_hash[centre_name][week_begin] << [nbc,pbc.compact.uniq.size,sc.size]
  end
end

def get_row(d)
  line = ""
  $centre_abr.each do |k,v|
    nbc,pbc,sc = $centre_date_hash[k][d][0]
    # Add av no. samples/plate
    if pbc == 0
      av = 0
      pbc = 'None'
    else
      av = (sc/pbc.to_f).round(2)
    end
    line = line+"\t\t"+nbc.to_s+" "+pbc.to_s+" "+sc.to_s+" "+av.to_s
  end
  return "#{d.strftime('%d/%m/%Y')}#{line}"
end

def build_header()
  $centre_abr = {'Alderley' => 'AP', 'UK Biocentre' => 'MK', 'Queen Elizabeth University Hospital' => 'GW', 'Cambridge-az' => 'CB'}
  header = "Week\t"
  sub_header = "\t"
  i=0
  $centre_abr.each do |k,abr|
    header = "#{header}"+"\t\t"+abr if i==0
    header = "#{header}"+"\t\t\t"+abr if i > 0
    sub_header = sub_header+"\t\t"+"-Pc +Pc Sc S/P"
    i +=1
  end
  return header, sub_header
end

def print_out_data()
  header, sub_header = build_header()
  puts header
  puts sub_header
  @dates.each do |d|
    row = get_row(d)
    puts row
  end; nil
end

def build_data_for_weeks_previous(number,positive_samples_file,negative_barcode_file)
  data = get_file(positive_samples_file)
  data.shift # remove header
  build_negative_hash(negative_barcode_file)
  build_hash(data)
  $ap_date_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_date_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_date_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_date_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_date_hash = {'Alderley' => $ap_date_hash,
                 'UK Biocentre' => $mk_date_hash,
                 'Queen Elizabeth University Hospital' => $gla_date_hash,
                 'Cambridge-az' => $cb_date_hash
                }
  @dates=[]
  c=number-1
  while c > -1
    week_begin = Date.today.weeks_ago(c).beginning_of_week(:monday)
    # puts week_begin
    @dates << week_begin
    get_week_data(week_begin)
    c -=1
  end
  print_out_data
end
