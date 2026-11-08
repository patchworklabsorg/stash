# frozen_string_literal: true

# Include this concern in models that need full-text search
#
# Usage:
#   class Post < ApplicationRecord
#     include Searchable
#     searchable_by :title, :body
#   end
#
#   Post.search("hello world")
#
# Advanced usage with weights:
#   class Post < ApplicationRecord
#     include Searchable
#     searchable_by title: 'A', body: 'B', author_name: 'C'
#   end
#
# With associations:
#   class Post < ApplicationRecord
#     include Searchable
#     searchable_by :title, :body, associated: { comments: :content }
#   end
#
module Searchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
  end

  class_methods do
    def searchable_by(*columns, associated: nil, **weighted_columns)
      tsearch_options = {
        prefix: true,
        dictionary: 'english',
        tsvector_column: 'searchable'
      }

      against = if weighted_columns.any?
        weighted_columns.transform_values { |weight| weight.to_sym }
      else
        columns
      end

      search_config = {
        against: against,
        using: {
          tsearch: tsearch_options
        }
      }

      if associated
        search_config[:associated_against] = associated
      end

      pg_search_scope :search, **search_config

      # Also add a ranked search that includes the rank
      pg_search_scope :search_with_rank, **search_config.merge(ranked_by: ':tsearch')
    end
  end
end
