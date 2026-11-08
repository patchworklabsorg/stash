# Caching Strategies

## Fragment Caching (Views)

Basic fragment cache:
```erb
<% cache @user do %>
  <%= @user.name %>
<% end %>
```

## Russian Doll Caching

Nested caches that auto-expire:
```erb
<% cache @project do %>
  <h1><%= @project.name %></h1>
  <%= render @project.tasks %>
<% end %>

<!-- _task.html.erb -->
<% cache task do %>
  <%= task.name %>
<% end %>
```

**Important:** Use `touch: true` on associations:
```ruby
class Task < ApplicationRecord
  belongs_to :project, touch: true
end
```

## Model Caching (IdentityCache)

```ruby
class User < ApplicationRecord
  include Cacheable

  cache_index :email
  cache_has_many :posts, embed: true
end

# Usage
User.fetch(1)                    # Cached
User.fetch_by_email('a@b.com')   # Cached
user.fetch_posts                 # Cached with user
```

## Low-Level Caching

```ruby
Rails.cache.fetch('expensive_operation', expires_in: 1.hour) do
  ExpensiveService.call
end
```

## Cache Warming

```ruby
# Run periodically
CacheWarmerJob.perform_later

# Or specific caches
CacheWarmerJob.perform_later(caches: ['users'])
```
