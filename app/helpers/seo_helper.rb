# frozen_string_literal: true

# Usage in controllers or views:
#   set_meta_tags title: 'Page Title',
#                 description: 'Page description',
#                 keywords: 'keyword1, keyword2'
#
# Or use the helpers:
#   page_title 'My Page'
#   page_description 'Description here'
#
module SeoHelper
  def page_title(title)
    set_meta_tags title: title
  end

  def page_description(description)
    set_meta_tags description: description
  end

  def page_image(image_url)
    set_meta_tags og: { image: image_url },
                  twitter: { image: image_url }
  end

  # Full SEO setup for a page
  def page_seo(title:, description: nil, image: nil, type: 'website')
    tags = {
      title: title,
      og: { title: title, type: type },
      twitter: { card: 'summary_large_image', title: title }
    }

    if description
      tags[:description] = description
      tags[:og][:description] = description
      tags[:twitter][:description] = description
    end

    if image
      tags[:og][:image] = image
      tags[:twitter][:image] = image
    end

    set_meta_tags tags
  end
end
