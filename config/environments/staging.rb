# Staging runs with the production settings. Only the safety checks differ: in staging, every
# page shows the construction border and the STAGING label (ApplicationHelper#staging_environment?).
# The dev sign-in is refused as in production. See Stash::Deployment and docs/deploy.md.
require_relative "production"
