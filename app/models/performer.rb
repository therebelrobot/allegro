class Performer < ActiveRecord::Base
  ## example of how to override param in routes
  # def to_param
  #   return "#{name.parameterize}"
  # end
  has_many :attendance_records
  has_many :registrations
end
