# frozen_string_literal: true

module Auditable
  extend ActiveSupport::Concern

  included do
    has_paper_trail
  end

  def audit_trail
    versions.order(created_at: :desc)
  end

  def last_modified_by
    versions.last&.whodunnit
  end
end
