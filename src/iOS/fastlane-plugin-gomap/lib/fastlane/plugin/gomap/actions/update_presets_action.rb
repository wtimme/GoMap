require 'fastlane/action'
require_relative '../helper/gomap_helper'
require "open-uri"
require "fileutils"
require "json"
require "set"

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
        download_json(address_formats_url, address_formats_file)

        categories_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/preset_categories.min.json"
        categories_file = "../presets/categories.json"
        download_json(categories_url, categories_file)

        defaults_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/preset_defaults.min.json"
        defaults_file = "../presets/defaults.json"
        download_json(defaults_url, defaults_file)

        fields_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/preset_fields.min.json"
        fields_file = "../presets/fields.json"
        download_json(fields_url, fields_file)

        presets_url = "https://raw.githubusercontent.com/openstreetmap/iD/#{tag}/dist/data/preset_presets.min.json"
        presets_file = "../presets/presets.json"
        download_json(presets_url, presets_file)
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

      def self.update_icons()
        presets_file = "../presets/presets.json"

        file = File.read(presets_file)
        data_hash = JSON.parse(file)

        font_awesome_regular_icons = Set.new
        font_awesome_solid_icons = Set.new
        id_svg_poi_icons = Set.new
        maki_icons = Set.new
        temaki_icons = Set.new
        tnp_icons = Set.new
        unsupported_icons = Set.new
        data_hash.each do |_, preset_details|
          prefixed_icon_name = preset_details["icon"]

          if prefixed_icon_name.nil?
            # Ignore `nil`
          elsif prefixed_icon_name.start_with?("far-")
            font_awesome_regular_icons.add(prefixed_icon_name)
          elsif prefixed_icon_name.start_with?("fas-")
            font_awesome_solid_icons.add(prefixed_icon_name)
          elsif prefixed_icon_name.start_with?("iD-")
            id_svg_poi_icons.add(prefixed_icon_name)
          elsif prefixed_icon_name.start_with?("maki-")
            maki_icons.add(prefixed_icon_name)
          elsif prefixed_icon_name.start_with?("temaki-")
            temaki_icons.add(prefixed_icon_name)
          elsif prefixed_icon_name.start_with?("tnp-")
            tnp_icons.add(prefixed_icon_name)
          else
            unsupported_icons.add(prefixed_icon_name)
          end
        end

        UI.message("Found #{font_awesome_regular_icons.size} Regular Font Awesome icons.")
        UI.message("Found #{font_awesome_solid_icons.size} Solid Font Awesome icons.")
        UI.message("Found #{id_svg_poi_icons.size} iD SVG POI icons.")
        UI.message("Found #{maki_icons.size} Maki icons.")
        UI.message("Found #{temaki_icons.size} Temaki icons.")
        UI.message("Found #{tnp_icons.size} TNP icons.")

        unless unsupported_icons.empty?
          UI.message("#{unsupported_icons.size} icons are not supported at the moment: #{unsupported_icons}")
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
