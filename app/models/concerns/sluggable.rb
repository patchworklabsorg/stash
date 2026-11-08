# frozen_string_literal: true

# Include this concern in models that need URL slugs
#
# Migration:
#   add_column :posts, :slug, :string
#   add_index :posts, :slug, unique: true
#
# Usage:
#   class Post < ApplicationRecord
#     include Sluggable
#     slugged_by :title
#   end
#
#   post = Post.create(title: "Hello World")
#   post.slug  # => "hello-world"
#   Post.friendly.find("hello-world")
#
# With history (redirects old slugs):
#   class Post < ApplicationRecord
#     include Sluggable
#     slugged_by :title, history: true
#   end
#
module Sluggable
  extend ActiveSupport::Concern

  included do
    extend FriendlyId
  end

  class_methods do
    def slugged_by(attribute, history: false, scope: nil)
      options = { use: [:slugged] }
      options[:use] << :history if history
      options[:use] << :scoped if scope
      options[:scope] = scope if scope

      friendly_id attribute, **options
    end
  end
end
