# frozen_string_literal: true

# Include this concern and use the DSL to encrypt sensitive fields
#
# Example:
#   class User < ApplicationRecord
#     include Encryptable
#
#     encrypts_field :ssn
#     encrypts_field :phone, searchable: true
#   end
#
# Migration for encrypted fields:
#   add_column :users, :ssn_ciphertext, :text
#   add_column :users, :phone_ciphertext, :text
#   add_column :users, :phone_bidx, :string  # for searchable fields
#   add_index :users, :phone_bidx
#
module Encryptable
  extend ActiveSupport::Concern

  class_methods do
    def encrypts_field(field_name, searchable: false)
      encrypts field_name

      if searchable
        blind_index field_name
      end
    end
  end
end
