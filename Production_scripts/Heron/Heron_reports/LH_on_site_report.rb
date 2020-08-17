def get_file(filename)
  data = CSV.read("/var/tmp/Heron_tmp/Files/#{filename}.csv")
  return data
end

def write_to_named_file(line,output_filename)
  CSV.open("/var/tmp/Heron_tmp/Files/#{output_filename}.csv", "a+") do |csv|
    csv << line
  end
end

def build_hash(data)
  $ap_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_hash = {'Alderley' => $ap_hash,
                  'Cambridge-az' => $cb_hash,
                  'Queen Elizabeth University Hospital' => $gla_hash,
                  'UK Biocentre' => $mk_hash
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
                      'Cambridge-az' => $cb_neg_hash,
                      'Queen Elizabeth University Hospital' => $gla_neg_hash,
                      'UK Biocentre' => $mk_neg_hash
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
  csv_data = [d]
  sum_nbc=0;sum_pbc=0;sum_sc=0
  $centre_abr.each do |k,v|
    nbc,pbc,sc = $centre_date_hash[k][d][0]
    if nbc == 'None'
      sum_nbc += 0
    else
      sum_nbc += nbc
    end
    sum_pbc += pbc
    sum_sc += sc
    # Add av no. samples/plate
    if pbc == 0
      av = 0
      pbc = 'None'
    else
      av = (sc/pbc.to_f).round(2)
    end
    [nbc,pbc,sc,av].each {|e| csv_data << e}
    line = line+"\t\t"+nbc.to_s+" "+pbc.to_s+" "+sc.to_s+" "+av.to_s
  end
  
  if sum_pbc == 0
    sum_av = 0
  else
    sum_av = (sum_sc/sum_pbc.to_f).round(2)
  end
  [sum_nbc,sum_pbc,sum_sc,sum_av].each {|e| csv_data << e}
  line = line+"\t"+sum_nbc.to_s+" "+sum_pbc.to_s+" "+sum_sc.to_s+" "+sum_av.to_s
  
  return "#{d.strftime('%d/%m/%Y')}#{line}", csv_data
end

def build_header()
  $centre_abr = {'Alderley' => 'AP', 'Cambridge-az' => 'CB', 'Queen Elizabeth University Hospital' => 'GW', 'UK Biocentre' => 'MK'}
  header = "\t"; sub_header = "Week\t"
  csv_header = [nil]; csv_sub_header = ["Week beginning"]
  labels = ['neg plates','pos plates','samples','avg']
  $centre_abr.keys.each do |k|
    csv_header << k
    3.times {csv_header << nil}
  end
  csv_header << 'All sites'
  i=0
  $centre_abr.each do |k,abr|
    header = "#{header}"+"\t\t"+abr if i==0
    header = "#{header}"+"\t\t\t"+abr if i > 0
    sub_header = sub_header+"\t\t"+"-Pc +Pc Sc S/P"
    labels.each {|e| csv_sub_header << e}
    i +=1
  end
  labels.each {|e| csv_sub_header << e}
  return header, sub_header, csv_header, csv_sub_header
end

def print_out_data(output_filename)
  header, sub_header, csv_header, csv_sub_header = build_header()
  puts header
  write_to_named_file(csv_header,output_filename)
  puts sub_header
  write_to_named_file(csv_sub_header,output_filename)
  @dates.each do |d|
    row, csv_row = get_row(d)
    puts row
    write_to_named_file(csv_row,output_filename)
  end; nil
end

def build_data_for_weeks_previous(number_of_weeks,positive_samples_file,negative_barcode_file,output_filename)
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
  c=0
  until c == number_of_weeks
    week_begin = Date.today.weeks_ago(c).beginning_of_week(:monday)
    # puts week_begin
    @dates << week_begin
    get_week_data(week_begin)
    c +=1
  end
  print_out_data(output_filename)
end
