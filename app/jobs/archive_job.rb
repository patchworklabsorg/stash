# Plans an archive: asks the server what the URL serves, picks the capture methods, makes the
# capture rows and enqueues one CaptureJob per capture.
class ArchiveJob < ApplicationJob
  queue_as :captures

  def perform(archive)
    return if archive.captures.exists?

    content_type = Capturers::Download.content_type(archive.url)
    archive.kind = Capturers::Router.kind_for(archive.url, content_type: content_type)
    methods = Capturers::Router.methods_for(archive.url, content_type: content_type)
    Archive.transaction do
      archive.save!
      methods.each_with_index do |method_name, position|
        archive.captures.create!(method_name: method_name, position: position)
      end
    end
    archive.captures.each { |capture| CaptureJob.perform_later(capture) }
  end
end
