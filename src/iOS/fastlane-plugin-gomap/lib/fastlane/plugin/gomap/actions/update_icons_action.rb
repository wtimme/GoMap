require 'fastlane/action'
require_relative '../helper/gomap_helper'
require "open-uri"
require "fileutils"
require "set"

module Fastlane
  module Actions
    class UpdateIconsAction < Action
      def self.run(params)
        update_icons
      end

      def self.update_icons()
        presets_file = "../presets/presets.json"

        UI.message("Reading icons names from presets.json...")

        file = File.read(presets_file)
        data_hash = JSON.parse(file)

        font_awesome_icons = Set.new
        id_svg_poi_icons = Set.new
        maki_icons = Set.new
        temaki_icons = Set.new
        tnp_icons = Set.new
        unsupported_icons = Set.new
        data_hash.each do |_, preset_details|
          prefixed_icon_name = preset_details["icon"]

          if prefixed_icon_name.nil?
            # Ignore `nil`
          elsif prefixed_icon_name.start_with?("far-") || prefixed_icon_name.start_with?("fas-")
            font_awesome_icons.add(prefixed_icon_name)
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

        UI.message("Finished reading icon names from presets.")
        UI.verbose("- #{font_awesome_icons.size} Font Awesome icons")
        UI.verbose("- #{id_svg_poi_icons.size} iD SVG POI icons")
        UI.verbose("- #{maki_icons.size} Maki icons")
        UI.verbose("- #{temaki_icons.size} Temaki icons")
        UI.verbose("- #{tnp_icons.size} TNP icons")

        total_number_of_icons = font_awesome_icons.size +
          id_svg_poi_icons.size +
          maki_icons.size +
          temaki_icons.size +
          tnp_icons.size
        UI.success("Found #{total_number_of_icons} icons.")

        unless unsupported_icons.empty?
          UI.message("#{unsupported_icons.size} icons are not supported at the moment: #{unsupported_icons}")
        end

        downloadFontAwesomeIcons(font_awesome_icons)
      end

      def self.downloadFontAwesomeIcons(icons)
        tag = "5.14.0"
        path = "../POI-Icons/Font Awesome Icons.xcassets"

        icons.each do |prefixed_icon_name|
          icon_name = ""
          directory = ""
          if prefixed_icon_name.start_with?("far-")
            icon_name = prefixed_icon_name.delete_prefix("far-")
            directory = "regular"
          elsif prefixed_icon_name.start_with?("fas-")
            icon_name = prefixed_icon_name.delete_prefix("fas-")
            directory =  "solid"
          else
            UI.error("Unsupported icon prefix: #{prefixed_icon_name}")
          end

          url = "https://raw.githubusercontent.com/FortAwesome/Font-Awesome/#{tag}/svgs/#{directory}/#{icon_name}.svg"
          imageset_path = "#{path}/#{prefixed_icon_name}.imageset"
          svg_path = "#{imageset_path}/#{prefixed_icon_name}.svg"
          pdf_path = "#{imageset_path}/#{prefixed_icon_name}.pdf"

          # Make sure the path of the imageset exists.
          unless File.directory?(imageset_path)
            FileUtils.mkdir_p(imageset_path)
          end

          download_svg(url, svg_path)
        end
      end

      def self.download_svg(url, path)
        case io = open(url)
        when StringIO then File.open(path, 'w') { |f| f.write(io.string) }
        when Tempfile then io.close; FileUtils.mv(io.path, path)
        end
      end

      def self.description
        "Action that updates the icons used by GoMap!!"
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
