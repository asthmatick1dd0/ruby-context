# frozen_string_literal: true

require "spec_helper"

RSpec.describe Context do
  describe ".background" do
    subject(:background) { described_class.background }

    it "returns the same instance every time" do
      expect(described_class.background).to be(described_class.background)
    end

    it "is not cancelable" do
      expect(background.instance_variable_get(:@cancelable)).to be(false)
    end

    it "is never done" do
      expect(background.done?).to be(false)
    end

    it "has no error" do
      expect(background.err).to be_nil
    end

    it "does not create a new object on repeated calls" do
      first = described_class.background
      second = described_class.background

      expect(first.object_id).to eq(second.object_id)
    end
  end
end