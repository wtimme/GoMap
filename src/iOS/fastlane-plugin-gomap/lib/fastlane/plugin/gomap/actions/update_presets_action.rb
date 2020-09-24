require 'fastlane/action'
require_relative '../helper/gomap_helper'

module Fastlane
  module Actions
    class UpdatePresetsAction < Action
      def self.run(params)
        UI.message("This is the update_presets action")
      end

      def self.description
        "Action that automates the update process for iD presets"
      end

      def self.authors
        ["wtimme"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
