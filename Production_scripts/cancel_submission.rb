def find_submission(id)
  if id.is_a?(Integer)
    sub = Submission.find_by(id: id)
  else
    sub = Submission.find_by(name: id)
  end
  return sub
end

def cancel_submission(sub_identifiers)
  ActiveRecord::Base.transaction do
    sub_identifiers.each do |id|
      sub = find_submission(id)
      puts id
      sub.requests.each do |req|
        if req.state == 'pending'
          req.cancel_before_started!
        else
          req.cancel! unless req.state == 'cancelled' || req.state == 'failed'
        end
      end
      # TransferRequest.where(submission_id: sub.id).select {|tr| tr.state != 'failed' || tr.state != 'cancelled'}.map(&:cancel!); nil
      sub.reload
      if sub.requests.map(&:state).uniq == ['cancelled']
        sub.cancel!
        puts "sub #{id} #{sub.state}"
      else
        puts "sub #{id} #{sub.requests.map(&:state).uniq}"
      end
    end
  end
end

# cancel_submission([])