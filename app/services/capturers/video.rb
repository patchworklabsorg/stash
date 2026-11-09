module Capturers
  # A video through yt-dlp: the media file (original), yt-dlp's info JSON (metadata) and the
  # poster (screenshot). Playlists are never pulled: one URL, one video.
  class Video < Base
    FORMAT = "bv*[height<=1080]+ba/b[height<=1080]/b".freeze

    def call
      command = [
        "yt-dlp", "--no-playlist", "--no-progress", "--no-color", "--no-cache-dir",
        "--write-info-json", "--write-thumbnail", "--convert-thumbnails", "png",
        "--format", FORMAT, "--merge-output-format", "mp4",
        "--max-filesize", Capturers.max_bytes.to_s,
        "--output", "video.%(ext)s"
      ]
      command += [ "--cookies", ENV["YTDLP_COOKIES_FILE"] ] if ENV["YTDLP_COOKIES_FILE"].present?
      command += [ "--proxy", ENV["YTDLP_PROXY"] ] if ENV["YTDLP_PROXY"].present?
      command << "--" << url
      classify_tool_failure("yt-dlp",
        not_public: [ /Private video/i, /This video is private/i, /Sign in to confirm/i, /members-only/i,
                      /login required/i, /requires authentication/i, /not available to you/i ],
        not_found: [ /Video unavailable/i, /has been removed/i, /does not exist/i, /HTTP Error 404/i,
                     /Unsupported URL/i, /no video/i ]) do
        run!(*command, env: { "HOME" => workdir })
      end

      media = Dir.glob(path("video.*")).reject { |f| f.end_with?(".info.json", ".png") }.first
      raise ToolFailed, "yt-dlp wrote no media file" unless media

      outputs = [ output("original", ::File.basename(media), content_type: Marcel::MimeType.for(Pathname.new(media))) ]
      outputs << output("metadata", "video.info.json", content_type: "application/json") if ::File.exist?(path("video.info.json"))
      outputs << output("screenshot", "video.png", content_type: "image/png") if ::File.exist?(path("video.png"))
      outputs
    end
  end
end
