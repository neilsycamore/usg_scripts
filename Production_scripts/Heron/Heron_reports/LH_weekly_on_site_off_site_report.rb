def get_file(filename)
  data = CSV.read("/var/tmp/#{filename}.csv")
  return data
end

def write_to_named_file(line,output_filename)
  CSV.open("/var/tmp/#{output_filename}.csv", "a+") do |csv|
    csv << line
  end
end

def get_barcodes(data)
  barcodes=[]
  data.each {|l| barcodes << l[1]}
  return barcodes.uniq
end

def find_on_site_barcodes(all_barcodes)
  all_barcodes.each_slice(1000) do |barcodes|
    Labware.where(barcode: barcodes).each do |l|
      $on_site_hash[l.barcode] = l.created_at.strftime('%d/%m/%Y') # scanned in date
    end
  end
end

def on_site_barcodes(positive_samples_file,negative_barcode_file)
  @pos_data = get_file(positive_samples_file)
  @pos_data.shift # remove header
  @neg_data = get_file(negative_barcode_file)
  @neg_data.pop # the last line of the file is centre,barcode,date_tested.. not sure why yet
  pos_barcodes = get_barcodes(@pos_data); nil
  neg_barcodes = get_barcodes(@neg_data); nil
  all_barcodes = []
  barcodes = neg_barcodes + pos_barcodes; nil
  all_barcodes = barcodes.uniq; nil
  find_on_site_barcodes(all_barcodes)
end

def build_pos_hashes()
  $ap_pos_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_pos_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_pos_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_pos_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_pos_hash = {'Alderley' => $ap_pos_hash,
                  'Cambridge-az' => $cb_pos_hash,
                  'Queen Elizabeth University Hospital' => $gla_pos_hash,
                  'UK Biocentre' => $mk_pos_hash
                  }
                  
  $ap_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }

  $centre_offsite_hash = {'Alderley' => $ap_offsite_hash,
                  'Cambridge-az' => $cb_offsite_hash,
                  'Queen Elizabeth University Hospital' => $gla_offsite_hash,
                  'UK Biocentre' => $mk_offsite_hash
                  }
  
  puts "build_pos_hashes"
  c = @pos_data.size
  @pos_data.each do |centre, barcode, sample_id, result, dtime|
    print "\r#{c}"
    tested_date = dtime.to_date.strftime('%d/%m/%Y')
    $centre_offsite_hash[centre][tested_date] << [barcode,sample_id] # store offsite tested at date
    date = $on_site_hash[barcode] # scanned in date
    if date.nil?
      c -=1
      next
    else
      $centre_pos_hash[centre][date] << [barcode,sample_id] # store on site data by scanned in date
      c -=1
    end
  end; nil
end

def build_neg_hash()
  $ap_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_neg_hash = {'Alderley' => $ap_neg_hash,
                      'Cambridge-az' => $cb_neg_hash,
                      'Queen Elizabeth University Hospital' => $gla_neg_hash,
                      'UK Biocentre' => $mk_neg_hash
                      }
  puts "build_neg_hash"

  c = @neg_data.size
  @neg_data.each do |centre,barcode,dtime|
    print "\r#{c}"
    date = $on_site_hash[barcode] # scanned in date
    if date.nil?
      c -=1
      next
    else
      $centre_neg_hash[centre][date] << barcode # store on site barcodes that contain a negative sample by scanned in date
      c -=1
    end
  end; nil
end

def get_week_data(week_begin)
  $centre_pos_hash.each do |centre_name,hash|
    range = week_begin..week_begin+6
    pbc=[];os_bc=[] # pbc Positive Barcode Count; os_bc Offsite barcode Count
    hash.each do |k,values|
      if range.cover?(k.to_date)
        values.each do |b,s|
          pbc << b # 1:1 barcode to sample therefore only need to record barcode (total count = sample count, uniq count = barcode count)
        end
      end
    end
    $centre_offsite_hash[centre_name].each do |k,values|
      if range.cover?(k.to_date)
        values.each do |b,s|
          os_bc << b
        end
      end
    end
    negative_dates = []
    $centre_neg_hash[centre_name].each do |d,stuff|
      negative_dates << d if range.cover?(d.to_date)
    end
    if negative_dates.present?
      range_negative_barcodes = []
      negative_dates.each do |date|
        $centre_neg_hash[centre_name][date].each {|b| range_negative_barcodes << b}
      end
      # nbc = range_negative_barcodes.uniq.difference(pbc.uniq).size; nil # nbc Negative Barcode Count # .difference doesn't work on labw-prod
      negative_barcodes = range_negative_barcodes.reject{|x| pbc.uniq.include? x}; nil
      nbc = negative_barcodes.size
    else
      nbc = 'None'
    end   
    $centre_date_hash[centre_name][week_begin.strftime('%d/%m/%Y')] << [nbc,pbc.compact.uniq.size,pbc.compact.size,os_bc.compact.uniq.size,os_bc.compact.size]
  end
end

def get_row(d)
  line = ""
  csv_data = [d]
  sum_nbc=sum_pbc=sum_sc=sum_os_bc=sum_os_sc=0
  $centre_abr.each do |k,v|
    nbc,pbc,sc,os_bc,os_sc = $centre_date_hash[k][d][0]
    if nbc == 'None' #|| nbc.nil?
      sum_nbc += 0
    else
      sum_nbc += nbc
    end
    sum_pbc += pbc
    sum_sc += sc
    sum_os_bc += os_bc
    sum_os_sc += os_sc
    # Add av no. samples/plate
    if pbc == 0
      av = 0
      pbc = 'None'
    else
      av = (sc/pbc.to_f).round(2)
    end
    if os_bc == 0 #|| os_bc.nil?
      os_av = 0
    else
      os_av = (os_sc/os_bc.to_f).round(2)
    end
    [nbc,pbc,sc,av,os_sc,os_av].each {|e| csv_data << e}
    line = line+"\t\t"+nbc.to_s+" "+pbc.to_s+" "+sc.to_s+" "+av.to_s+" "+os_sc.to_s+" "+os_av.to_s
  end 
  if sum_pbc == 0
    sum_av = 0
  else
    sum_av = (sum_sc/sum_pbc.to_f).round(2)
  end
  if sum_os_bc == 0
    sum_os_av = 0
  else
    sum_os_av = (sum_os_sc/sum_os_bc.to_f).round(2)
  end
  [sum_nbc,sum_pbc,sum_sc,sum_av,sum_os_sc,sum_os_av].each {|e| csv_data << e}
  line = line+"\t"+sum_nbc.to_s+" "+sum_pbc.to_s+" "+sum_sc.to_s+" "+sum_av.to_s+" "+sum_os_sc.to_s+" "+sum_os_av.to_s
  
  return "#{d}#{line}", csv_data
end

def build_header()
  $centre_abr = {'Alderley' => 'AP', 'Cambridge-az' => 'CB', 'Queen Elizabeth University Hospital' => 'GW', 'UK Biocentre' => 'MK'}
  header = "\t"; sub_header = "Week number\tWeek\t"
  csv_header = [nil,nil]; csv_sub_header = ["Week number","Week beginning"]
  labels = ['neg plates','pos plates','samples','avg','samples tested','avg samples tested']
  $centre_abr.keys.each do |k|
    csv_header << k
    5.times {csv_header << nil}
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

def find_weeks_from_week_zero(d)
  week_zero = '20/07/2020'.to_date
  week_count = (d.to_date-week_zero).to_i/7
  return week_count
end

def print_out_data(output_filename)
  header, sub_header, csv_header, csv_sub_header = build_header()
  puts header
  write_to_named_file(csv_header,output_filename)
  puts sub_header
  write_to_named_file(csv_sub_header,output_filename)
  @dates.each do |d|
    row, csv_row = get_row(d)
    week_count = find_weeks_from_week_zero(d)
    puts "#{week_count}\t#{row}"
    csv_row.unshift(week_count)
    write_to_named_file(csv_row,output_filename)
  end; nil
end

def build_data_for_weeks_previous(number_of_weeks,positive_samples_file,negative_barcode_file,output_filename)
  $on_site_hash = Hash.new
  pos_data = get_file(positive_samples_file)
  neg_data = get_file(negative_barcode_file)
  pos_barcodes = get_barcodes(pos_data)
  neg_barcodes = get_barcodes(neg_data)
  on_site_barcodes(positive_samples_file,negative_barcode_file); nil
  build_pos_hashes
  build_neg_hash
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
    @dates << week_begin.strftime('%d/%m/%Y')
    get_week_data(week_begin)
    c +=1
  end
  print_out_data(output_filename)
end
# build_data_for_weeks_previous(4,'pos_samples_180920','neg_plate_barcodes_180920','180920_wk_on_wk_4_test_1')

