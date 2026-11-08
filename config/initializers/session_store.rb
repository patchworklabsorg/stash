# The session is an encrypted cookie. It holds the signed-in user's Weave sub, name, roles and sign-in time.
# The cookie expires after 8 hours. The Authentication concern also checks the sign-in time on each request.
# SameSite=Lax lets the cookie come back on the top-level redirect from Weave to /auth/callback.
Rails.application.config.session_store :cookie_store,
  key: "_stash_session",
  expire_after: Rails.application.config.x.session_lifetime,
  same_site: :lax,
  secure: !Rails.env.local?,
  httponly: true
