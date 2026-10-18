require 'rails_helper'

RSpec.describe Ethon do
  it 'logger does not log request URLs (which include the Gemini API key) at debug level' do
    expect(described_class.logger.debug?).to be(false)
  end
end
