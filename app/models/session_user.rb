# The signed-in person, as stored in the session. Keyed on the Weave `sub` (the PWL id), never on email.
#
# The roles come from Weave at sign-in and are trusted until the session expires. Stash stores
# the sub only: the name and email live in the cookie for display and are never written to the database.
SessionUser = Data.define(:sub, :name, :email, :roles, :signed_in_at) do
  def self.from_session(data)
    return nil unless data.is_a?(Hash) && data["sub"].is_a?(String) && data["signed_in_at"].is_a?(Integer)

    new(
      sub: data["sub"],
      name: data["name"].to_s,
      email: data["email"].to_s,
      roles: Weave::Roles.from_claim(data["roles"]),
      signed_in_at: Time.zone.at(data["signed_in_at"])
    )
  end

  def to_session
    { "sub" => sub, "name" => name, "email" => email, "roles" => roles, "signed_in_at" => signed_in_at.to_i }
  end

  def expired?(now = Time.current)
    signed_in_at + Rails.configuration.x.session_lifetime <= now
  end

  # viewer, archivist and admin can all open archives.
  def reader?
    roles.any?
  end

  # archivist and admin can archive a URL by hand and run an archive again.
  def archivist?
    roles.intersect?(%w[archivist admin])
  end

  def admin?
    roles.include?("admin")
  end

  def display_name
    name.presence || sub
  end
end
