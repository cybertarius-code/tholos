class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  add_flash_types :success, :error, :warning, :info

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Use in turbo_stream responses, where the layout is not rendered
  def flash_stream
    turbo_stream.update("flash", partial: "shared/flash_messages")
  end
end
