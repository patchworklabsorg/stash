# Models inherit CentralRecord, which names the database they live in. ApplicationRecord stays
# as the Rails base class, for engines (GoodJob, Active Storage) and for the default connection.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
