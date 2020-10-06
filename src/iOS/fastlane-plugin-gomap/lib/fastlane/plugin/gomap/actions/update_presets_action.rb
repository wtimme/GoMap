require 'fastlane/action'
require_relative '../helper/gomap_helper'
require "open-uri"
require "fileutils"
require "json"
require "net/http"

module Fastlane
  module Actions
    class UpdatePresetsAction < Action
      def self.run(params)
        @tag = get_latest_iD_tag
        @preset_directory = "../presets"

        downloadLatestPresets
      end

      def self.downloadLatestPresets()
        UI.message("Updating presets to #{@tag}...")

        update_address_formats()
        update_categories()
        update_defaults()
        update_fields()
        update_presets()
      end

      def self.get_latest_iD_tag()
        url = "https://api.github.com/repos/openstreetmap/iD/releases/latest"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        release_details = JSON.parse(response)

        release_details["tag_name"]
      end

      def self.update_address_formats()
        url = "https://raw.githubusercontent.com/openstreetmap/iD/#{@tag}/dist/data/address_formats.min.json"
        filename = "address-formats.json"

        update_preset_json(url, filename)
      end

      def self.update_categories()
        url = "https://raw.githubusercontent.com/openstreetmap/iD/#{@tag}/dist/data/preset_categories.min.json"
        filename = "categories.json"

        update_preset_json(url, filename)
      end

      def self.update_defaults()
        url = "https://raw.githubusercontent.com/openstreetmap/iD/#{@tag}/dist/data/preset_defaults.min.json"
        filename = "defaults.json"

        update_preset_json(url, filename)
      end

      def self.update_fields()
        url = "https://raw.githubusercontent.com/openstreetmap/iD/#{@tag}/dist/data/preset_fields.min.json"
        filename = "fields.json"

        update_preset_json(url, filename)
      end

      def self.update_presets()
        url = "https://raw.githubusercontent.com/openstreetmap/iD/#{@tag}/dist/data/preset_presets.min.json"
        filename = "presets.json"

        update_preset_json(url, filename)
      end

      def self.update_preset_json(url, filename)
        UI.message("Updating #{filename}...")

        file = "#{@preset_directory}/#{filename}"
        download_json(url, file)

        UI.success("Successfully updated #{filename}.")
      end

      def self.download_json(url, path)
        case io = open(url)
        when StringIO then File.open(path, 'w') { |f|
          json = JSON.parse(io.string)
          pretty_json = JSON.pretty_generate(json)

          f.write(pretty_json)
        }
        when Tempfile then io.close; FileUtils.mv(io.path, path)
        end
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
