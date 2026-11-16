module Settings
  module SessionsHelper
    BROWSERS = [
      [ /Edg(e|A|iOS)?\//, "Edge" ],
      [ /OPR\/|Opera/, "Opera" ],
      [ /Chrome|Chromium|CriOS/, "Chrome" ],
      [ /Firefox|FxiOS/, "Firefox" ],
      [ /Safari/, "Safari" ]
    ].freeze

    SYSTEMS = [
      [ /iPhone|iPad|iPod/, "iOS" ],
      [ /Android/, "Android" ],
      [ /Windows/, "Windows" ],
      [ /Macintosh|Mac OS X/, "macOS" ],
      [ /Linux/, "Linux" ]
    ].freeze

    def user_agent_summary(user_agent)
      return t("settings.sessions.unknown_device") if user_agent.blank?

      browser = BROWSERS.find { |pattern, _| user_agent.match?(pattern) }&.last || t("settings.sessions.unknown_browser")
      system = SYSTEMS.find { |pattern, _| user_agent.match?(pattern) }&.last || t("settings.sessions.unknown_system")

      "#{browser} · #{system}"
    end
  end
end
