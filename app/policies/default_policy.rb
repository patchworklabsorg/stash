# frozen_string_literal: true

# Default policy for records without a specific policy
# Used when Pundit cannot find a policy for a given record
class DefaultPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user == record_owner || user.admin_or_above?)
  end

  def destroy?
    user.present? && (user == record_owner || user.admin_or_above?)
  end

  private

  def record_owner
    record.respond_to?(:user) ? record.user : nil
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin_or_above?
        scope.all
      else
        scope.none
      end
    end
  end
end
