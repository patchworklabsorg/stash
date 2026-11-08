# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    user == record
  end

  def update?
    user == record
  end

  def destroy?
    user == record
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(id: user.id)
    end
  end
end
