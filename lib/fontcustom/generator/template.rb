require "json"
require "pathname"
require "thor"
require "thor/group"

module Fontcustom
  module Generator
    class Template < Thor::Group
      include Actions

      # Instead of passing each option individually we're passing the entire options hash as an argument.
      # This is DRYier, easier to maintain.
      argument :opts

      # Required for Thor::Actions#template
      def self.source_root
        File.join Fontcustom::Util.gem_lib_path, "templates"
      end

      def get_data
        data = File.join(opts[:project_root], ".fontcustom-data")
        if File.exists? data
          @data = JSON.parse(File.read(data), :symbolize_names => true)
        else
          raise Fontcustom::Error, "There's no .fontcustom-data file in #{opts[:project_root]}. Try again?"
        end
      rescue JSON::ParserError
        # Catches both empty and and malformed files
        raise Fontcustom::Error, "The .fontcustom-data file in #{opts[:project_root]} is empty or corrupted. Try deleting the file and running Fontcustom::Generator::Font again to regenerate .fontcustom-data."
      end

      def reset_output
        return if @data[:templates].empty?
        begin
          deleted = []
          @data[:templates].each do |file|
            remove_file file, :verbose => false
            deleted << file
          end
        ensure
          @data[:templates] = @data[:templates] - deleted
          json = JSON.pretty_generate @data
          file = File.join(opts[:project_root], ".fontcustom-data")
          clear_file(file)
          append_to_file file, json, :verbose => false
          say_changed :removed, deleted
        end
      end

      def make_relative_paths
        name = File.basename @data[:fonts].first, File.extname(@data[:fonts].first)
        fonts = Pathname.new opts[:output][:fonts]
        css = Pathname.new opts[:output][:css]
        preview = Pathname.new opts[:output][:preview]
        @data[:paths][:css_to_fonts] = File.join fonts.relative_path_from(css).to_s, name
        @data[:paths][:preview_to_css] = File.join css.relative_path_from(preview).to_s, "fontcustom.css"
        @data[:paths][:preprocessor_to_fonts] = if opts[:preprocessor_font_path] != ""
          File.join opts[:preprocessor_font_path], name
        else 
          @data[:paths][:css_to_fonts]
        end
      end

      def generate
        @opts = opts # make available to templates
        begin
          created = []
          opts[:templates].each do |source|
            name = File.basename source
            ext = File.extname name
            target = if opts[:output].keys.include? name
                       File.join opts[:output][name], name
                     elsif %w|.css .scss .sass .less .stylus|.include? ext
                       File.join opts[:output][:css], name
                     elsif name == "fontcustom-preview.html"
                       File.join opts[:output][:preview], name
                     else
                       File.join opts[:output][:fonts], name
                     end

            template source, target, :verbose => false
            created << target
          end
        ensure
          @data[:templates] = (@data[:templates] + created).uniq
          json = JSON.pretty_generate @data
          file = File.join(opts[:project_root], ".fontcustom-data")
          clear_file(file)
          append_to_file file, json, :verbose => false
          say_changed :created, created
        end
      end
    end
  end
end