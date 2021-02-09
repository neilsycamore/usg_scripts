def get_file(filename)
  data = CSV.read("/var/tmp/#{filename}.csv")
  data.shift # remove header
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
  @neg_data = get_file(negative_barcode_file)
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
  $rx_pos_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_pos_hash = {'Alderley' => $ap_pos_hash,
                  'Cambridge-az' => $cb_pos_hash,
                  'Queen Elizabeth University Hospital' => $gla_pos_hash,
                  'UK Biocentre' => $mk_pos_hash,
                  'Randox' => $rx_pos_hash
                  }
                  
  $ap_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $rx_offsite_hash = Hash.new{|hsh,key| hsh[key] = [] }

  $centre_offsite_hash = {'Alderley' => $ap_offsite_hash,
                  'Cambridge-az' => $cb_offsite_hash,
                  'Queen Elizabeth University Hospital' => $gla_offsite_hash,
                  'UK Biocentre' => $mk_offsite_hash,
                  'Randox' => $rx_offsite_hash
                  }
  
  puts "build_pos_hashes"
  c = @pos_data.size
  @pos_data.each do |centre, barcode, sample_id, result, dtime|
    print "\r#{c}"
    tested_date = dtime.to_date.strftime('%d/%m/%Y')
    scanned_in_date = $on_site_hash[barcode] # scanned in date
    $centre_offsite_hash[centre][tested_date] << [barcode,sample_id] # store offsite 'tested at' date
    if scanned_in_date.nil?
      c -=1
      next
    else
      $centre_pos_hash[centre][scanned_in_date] << [barcode,sample_id] # store on site data by scanned in date
      c -=1
    end
  end; nil
end

def build_neg_hash()
  $ap_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $gla_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $mk_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $cb_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  $rx_neg_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_neg_hash = {'Alderley' => $ap_neg_hash,
                      'Cambridge-az' => $cb_neg_hash,
                      'Queen Elizabeth University Hospital' => $gla_neg_hash,
                      'UK Biocentre' => $mk_neg_hash,
                      'Randox' => $rx_neg_hash
                      }
                      
  puts "build_neg_hash"

  c = @neg_data.size
  @neg_data.each do |centre,barcode,dtime|
    print "\r#{c}"
    scanned_in_date = $on_site_hash[barcode] # scanned in date
    if scanned_in_date.nil?
      c -=1
      next
    else
      $centre_neg_hash[centre][scanned_in_date] << barcode # store on site barcodes that contain a negative sample by scanned in date
      c -=1
    end
  end; nil
end

def get_week_data(week_begin)
  $centre_pos_hash.each do |centre_name,hash|
    range = week_begin..week_begin+6
    pbc=[];os_bc=[] # pbc Positive Barcode Count; os_bc Offsite barcode Count
    hash.each do |scanned_in_date,values|
      if range.cover?(scanned_in_date.to_date)
        values.each do |barcode,sample|
          pbc << barcode # 1:1 barcode to sample therefore only need to record barcode (total count = sample count, uniq count = barcode count)
        end
      end
    end
    $centre_offsite_hash[centre_name].each do |tested_date,values|
      if range.cover?(tested_date.to_date)
        values.each do |barcode,sample|
          os_bc << barcode
        end
      end
    end
    negative_dates = []
    $centre_neg_hash[centre_name].each do |scanned_in_date,stuff|
      negative_dates << scanned_in_date if range.cover?(scanned_in_date.to_date)
    end
    if negative_dates.present?
      range_negative_barcodes = []
      negative_dates.each do |scanned_in_date|
        $centre_neg_hash[centre_name][scanned_in_date].each {|b| range_negative_barcodes << b}
      end
      # nbc = range_negative_barcodes.uniq.difference(pbc.uniq).size; nil # nbc Negative Barcode Count # .difference doesn't work on labw-prod
      negative_barcodes = range_negative_barcodes.reject{|x| pbc.uniq.include? x}; nil
      negative_plate_count = negative_barcodes.size
    else
      negative_plate_count = 'None'
    end
    positive_plate_count  = pbc.compact.uniq.size
    positive_sample_count = pbc.compact.size
    off_site_positive_plate_count  = os_bc.compact.uniq.size
    off_site_positive_sample_count = os_bc.compact.size
    $centre_date_hash[centre_name][week_begin.strftime('%d/%m/%Y')] << [negative_plate_count,positive_plate_count,positive_sample_count,off_site_positive_plate_count,off_site_positive_sample_count]
  end
end

def get_row(date)
  # Glossary:
  # nbc => negative barcode count
  # pbc => positive barcode count
  # sc => sample count
  # os_bc => offsite barcode count
  # os_sc => offsite sample count
  # sum_nbc => summation of negative barcode count
  # sum_pbc => summation of positive barcode count
  # sum_sc => summation of sample count
  # sum_os_bc => summation of offsite barcode count
  # sum_os_sc => summation of offsite sample count
  # av = average positive sample per onsite plate
  # os_av = average positive sample per offsite plate
  line = ""
  csv_data = [date]
  sum_nbc=sum_pbc=sum_sc=sum_os_bc=sum_os_sc=0 # initialise counts
  $centre_abr.each do |centre,abr|
    nbc,pbc,sc,os_bc,os_sc = $centre_date_hash[centre][date][0]
    if nbc == 'None'
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
    if os_bc == 0
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
  
  return "#{date}#{line}", csv_data
end

def build_header()
  $centre_abr = {'Alderley' => 'AP', 'Cambridge-az' => 'CB', 'Queen Elizabeth University Hospital' => 'GW', 'UK Biocentre' => 'MK', 'Randox' => 'RX'}
  header = "\t"; sub_header = "Week number\tWeek\t"
  csv_header = [nil,nil]; csv_sub_header = ["Week number","Week beginning"]
  labels = ['neg plates','pos plates','samples','avg','samples tested','avg samples tested']
  $centre_abr.keys.each do |centre_name|
    csv_header << centre_name
    5.times {csv_header << nil}
  end
  csv_header << 'All sites'
  i=0
  $centre_abr.each do |centre_name,abr|
    header = "#{header}"+"\t\t"+abr if i==0
    header = "#{header}"+"\t\t\t"+abr if i > 0
    sub_header = sub_header+"\t\t"+"-Pc +Pc Sc Sav OSc OSav"
    labels.each {|e| csv_sub_header << e}
    i +=1
  end
  labels.each {|e| csv_sub_header << e}
  return header, sub_header, csv_header, csv_sub_header
end

def find_weeks_from_week_zero(date)
  week_zero = '20/07/2020'.to_date
  week_count = (date.to_date-week_zero).to_i/7
  return week_count
end

def print_out_data(output_filename)
  header, sub_header, csv_header, csv_sub_header = build_header()
  puts header
  write_to_named_file(csv_header,output_filename)
  puts sub_header
  write_to_named_file(csv_sub_header,output_filename)
  @dates.each do |date|
    row, csv_row = get_row(date)
    week_count = find_weeks_from_week_zero(date)
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
  $rx_date_hash = Hash.new{|hsh,key| hsh[key] = [] }
  
  $centre_date_hash = {'Alderley' => $ap_date_hash,
                 'UK Biocentre' => $mk_date_hash,
                 'Queen Elizabeth University Hospital' => $gla_date_hash,
                 'Cambridge-az' => $cb_date_hash,
                 'Randox' => $rx_date_hash
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
# build_data_for_weeks_previous(4,'pos_samples_090221','neg_plate_barcodes_090221','090221_wk_on_wk_4')
