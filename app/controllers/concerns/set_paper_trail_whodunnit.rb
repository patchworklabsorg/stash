# frozen_string_literal: true

module SetPaperTrailWhodunnit
  extend ActiveSupport::Concern

  included do
    before_action :set_paper_trail_whodunnit
  end

  private

  def user_for_paper_trail
    current_user&.id&.to_s || 'system'
  end
end
