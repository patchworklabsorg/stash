# The base class of every model in patchwork-central, schema "stash" (config/database.yml).
# Stash has one database connection, "central", so it is also the primary connection, and this
# class needs no connects_to. It names where the data lives, as RestrictedRecord does in Quilt.
# (A second connects_to to the same config would put Active Storage's rows on another connection
# pool, and the attachment upload after commit would never run.)
class CentralRecord < ApplicationRecord
  self.abstract_class = true

  # Finds a record by the id in a URL or an API call: the full public id (arc_4k8xJm2pN9qW) or the
  # bare encoded id that routes hold (4k8xJm2pN9qW). Anything else, a raw UUID included, is a 404.
  # This is the only lookup that controllers use; never find by primary key from a parameter.
  def self.find_by_public_param!(param)
    value = param.to_s
    value = value.delete_prefix("#{get_public_id_prefix}#{EncodedIds.configuration.separator}")
    uuid = value.present? && !value.include?("-") ? decode_to_uuid(value) : nil
    (uuid && find_by(id: uuid)) || raise(ActiveRecord::RecordNotFound, "Couldn't find #{name} with id=#{param}")
  end
end
