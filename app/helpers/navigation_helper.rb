# frozen_string_literal: true

# Navigation helpers using active_link_to
#
# Usage:
#   <%= nav_link_to 'Home', root_path %>
#   <%= nav_link_to 'Users', users_path, class: 'nav-item' %>
#
# The link gets an 'active' class when on that page.
# Customize with active_link_to options:
#   active: :exact         # Only exact URL match
#   active: :inclusive     # Match URL and sub-paths (default)
#   active: /regex/        # Match against regex
#   active: ['path1', 'path2']  # Match multiple paths
#
module NavigationHelper
  def nav_link_to(name, path, options = {})
    default_options = {
      class: 'nav-link',
      active_class: 'active'
    }
    active_link_to(name, path, default_options.merge(options))
  end

  # For nav items with icons
  def nav_link_with_icon(name, icon_class, path, options = {})
    content = tag.i(class: icon_class) + ' ' + name
    nav_link_to(content, path, options)
  end
end
