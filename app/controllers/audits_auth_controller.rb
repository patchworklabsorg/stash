# frozen_string_literal: true

class AuditsAuthController < ApplicationController
  before_action :require_super_admin
end
