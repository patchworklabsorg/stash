module ApplicationHelper
  # True on the staging deployment. That is RAILS_ENV=staging, or STASH_ENVIRONMENT=staging for
  # a deployment that runs with another Rails environment. Production never matches.
  def staging_environment?
    Rails.env.staging? || ENV["STASH_ENVIRONMENT"] == "staging"
  end

  # The color of each status word. The badge always shows the word too, so the color never carries
  # the meaning alone.
  STATUS_CLASSES = {
    "done" => "bg-emerald-100 text-emerald-900 dark:bg-emerald-900 dark:text-emerald-100",
    "running" => "bg-sky-100 text-sky-900 dark:bg-sky-900 dark:text-sky-100",
    "queued" => "bg-stone-100 text-stone-700 dark:bg-stone-800 dark:text-stone-300",
    "partial" => "bg-amber-100 text-amber-900 dark:bg-amber-900 dark:text-amber-100",
    "skipped" => "bg-stone-100 text-stone-600 dark:bg-stone-800 dark:text-stone-400",
    "failed" => "bg-rose-100 text-rose-900 dark:bg-rose-900 dark:text-rose-100"
  }.freeze

  def status_badge(status)
    return "" if status.blank?

    classes = STATUS_CLASSES.fetch(status.to_s, STATUS_CLASSES["queued"])
    content_tag(:span, status.to_s, class: "inline-block rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end

  # A header nav link. It is the current page (aria-current) when this action serves the section.
  def nav_link(label, path, section)
    current = section == "new" ? action_name == "new" : (controller_name == section && action_name != "new")
    link_to label, path, class: "#{current ? "text-stone-900 dark:text-stone-100 font-medium" : "text-stone-600 dark:text-stone-400"} hover:text-stone-900 dark:hover:text-stone-100",
      aria: { current: (current ? "page" : nil) }
  end
end
