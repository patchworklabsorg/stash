# frozen_string_literal: true

# Include this concern in models that should support soft deletes
#
# Migration:
#   add_column :posts, :deleted_at, :datetime
#   add_index :posts, :deleted_at
#
# Usage:
#   class Post < ApplicationRecord
#     include SoftDeletable
#   end
#
#   post.destroy          # soft deletes (sets deleted_at)
#   post.deleted?         # => true
#   post.recover          # restores the record
#   post.destroy_fully!   # permanently deletes
#
#   Post.all              # excludes soft-deleted records
#   Post.with_deleted     # includes soft-deleted records
#   Post.only_deleted     # only soft-deleted records
#
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    acts_as_paranoid
  end

  # Permanently delete the record
  def destroy_fully!
    destroy_fully
  end
end
