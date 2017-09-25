# frozen_string_literal: true
require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      class << self
        def call(package)
          errors = []
          package.svg_files.each do |svg|
            markup = svg.read
            clean_markup = Loofah.scrub_xml_document(markup, :prune).to_html
            filepath = svg.relative_path

            next if clean_markup == markup
            begin
              IO.write(filepath, clean_markup)
              package.warnings << I18n.t('txt.apps.admin.warning.sanitised_svg', svg: filepath)
            rescue
              errors << ValidationError.new(:dirty_svg, svg: filepath)
            end
          end
          errors
        end
      end
    end
  end
end