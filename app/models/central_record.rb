# The base class of every model in patchwork-central, schema "stash" (config/database.yml).
# Stash has one database connection, "central", so it is also the primary connection, and this
# class needs no connects_to. It names where the data lives, as RestrictedRecord does in Quilt.
# (A second connects_to to the same config would put Active Storage's rows on another connection
# pool, and the attachment upload after commit would never run.)
class CentralRecord < ApplicationRecord
  self.abstract_class = true
end
