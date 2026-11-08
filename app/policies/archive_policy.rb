# Who can do what with archives. The user is a SessionUser (roles from Weave), or nil.
#   viewer     index, show, download
#   archivist  also new, create, rerun
#   admin      also destroy
class ArchivePolicy < ApplicationPolicy
  def index?
    user&.reader? == true
  end

  def show?
    index?
  end

  def create?
    user&.archivist? == true
  end

  def rerun?
    create?
  end

  def destroy?
    user&.admin? == true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.reader? ? scope.all : scope.none
    end
  end
end
