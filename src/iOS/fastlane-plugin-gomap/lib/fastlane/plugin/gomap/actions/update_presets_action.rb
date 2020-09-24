require 'fastlane/action'
require_relative '../helper/gomap_helper'
require "open-uri"
require "fileutils"
require "json"

module Fastlane
  module Actions
    class UpdatePresetsAction < Action
      def self.run(params)
        downloadLatestPresets
      end

      def self.downloadLatestPresets()
        tag = "v2.18.5"

        address_formats_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/address_formats.min.json"
        address_formats_file = "../presets/address-formats.json"
        download(address_formats_url, address_formats_file)

        categories_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/preset_categories.min.json"
        categories_file = "../presets/categories.json"
        download(categories_url, categories_file)
      end

      def self.download(url, path)
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
