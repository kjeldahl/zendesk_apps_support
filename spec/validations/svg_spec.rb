# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Validations::Svg do
  let(:clean_markup) do
    %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10"></path></svg>\n)
  end
  let(:svg) { double('AppFile', relative_path: 'assets/icon_nav_bar.svg', read: markup) }
  let(:package) { double('Package', svg_files: [svg], warnings: []) }
  let(:warning) do
    'The markup in assets/icon_nav_bar.svg has been edited for use in Zendesk, and may not display as intended.'
  end

  before do
    allow(IO).to receive(:write)
  end

  context 'clean_markup' do
    let(:markup) { clean_markup }

    it 'leaves the original svg files unchanged when they contain well-formed, clean markup' do
      errors = ZendeskAppsSupport::Validations::Svg.call(package)
      expect(IO).not_to have_received(:write)
      expect(package.warnings).to be_empty
      expect(errors).to be_empty
    end
  end

  context 'dirty markup' do
    dirty_markup_examples = [
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10" onclick="alert(1)"></path></svg>\n),
      %(<svg onload=alert&#x28;1&#x29 viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"> \
<path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 \
23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg>\n),
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10"><script type="text/javascript">alert(1);</script></path></svg>\n),
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><script>//&NewLine;confirm(1); \
</script <path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 \
5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg>\n)
    ]

    dirty_markup_examples.map do |markup|
      let(:markup) { markup }
      it 'sanitises questionable markup and notifies the user that the offending svgs were modified' do
        errors = ZendeskAppsSupport::Validations::Svg.call(package)
        expect(IO).to have_received(:write).with(svg.relative_path, clean_markup)
        expect(package.warnings[0]).to eq(warning)
        expect(errors).to be_empty
      end
    end
  end

  context 'malformed markup' do
    malformed_markup_examples = [
      %(<svg onload=innerHTML=location.hash>#<script>alert(1)</script> viewBox="0 0 26 26" id="zd-svg-icon-26-app" \
width="100%" height="100%"><path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" \
d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"><script type="text/javascript">alert('XSS');</script> \
      </path></svg>\n),
      %(<svg onResize svg onResize="javascript:javascript:alert(1)" viewBox="0 0 26 26" id="zd-svg-icon-26-app" \
width="100%" height="100%"><path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" \
d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg onResize>\n)
    ]

    malformed_markup_examples.map do |markup|
      let(:markup) { markup }
      let(:empty_svg) { %(<svg></svg>\n) }

      it 'empties the contents of malformed svg tags and notifies the user that the offending svgs were modified' do
        errors = ZendeskAppsSupport::Validations::Svg.call(package)
        expect(IO).to have_received(:write).with(svg.relative_path, empty_svg)
        expect(package.warnings[0]).to eq(warning)
        expect(errors).to be_empty
      end
    end
  end

  context 'read-only error' do
    let(:markup) do
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10" onclick="alert(1)"></path></svg>\n)
    end

    before do
      allow(IO).to receive(:write).and_raise('Failed to write to original file')
    end

    it 'raises an error when a file contains questionable markup but it fails to be overwritten' do
      errors = ZendeskAppsSupport::Validations::Svg.call(package)
      expect(errors.size).to eq(1)
      expect(errors[0].key).to eq(:dirty_svg)
      expect(errors[0].data).to eq(svg: svg.relative_path)
    end
  end
end