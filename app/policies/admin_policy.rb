# frozen_string_literal: true

class AdminPolicy < ApplicationPolicy
  def blazer?
    user&.admin_or_above?
  end

  def flipper?
    user&.super_admin_or_above?
  end

  def rails_performance?
    user&.admin_or_above?
  end

  def jobs?
    user&.admin_or_above?
  end

  def console_audits?
    user&.super_admin_or_above?
  end

  def pghero?
    user&.admin_or_above?
  end

  def access_admin_endpoints?
    user&.admin_or_above?
  end
end
