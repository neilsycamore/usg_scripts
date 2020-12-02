class Sample
  def add_comment(rt_number, user)
    Comment.create!(title: "Consent withdrawn",commentable_id: self.id, commentable_type: self.class.name, user_id: user.id, description: "Request via RT#{rt_number}")
  end
end

def withdraw_sample_consent_and_add_comment(sample_names,user_login,rt_number)
  ActiveRecord::Base.transaction do
    user = User.find_by(login: user_login)
    Sample.where(name: sample_names).each do |sample|
      sample.update_attributes!(consent_withdrawn: true, date_of_consent_withdrawn: Date.today, user_id_of_consent_withdrawn: user.id)
      sample.add_comment(rt_number, user)
    end; nil
  end
end
