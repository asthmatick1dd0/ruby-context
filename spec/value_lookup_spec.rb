# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '#[]' do
    it 'returns value from current context' do
      ctx = described_class.with_value(described_class.background, :user, 'alice')

      expect(ctx[:user]).to eq('alice')
    end

    it 'returns value from parent context' do
      parent = described_class.with_value(described_class.background, :user, 'alice')
      child = described_class.with_value(parent, :request_id, '123')

      expect(child[:user]).to eq('alice')
    end

    it 'returns nil for unknown key' do
      ctx = described_class.with_value(described_class.background, :user, 'alice')

      expect(ctx[:missing]).to be_nil
    end

    it 'returns local value when key exists both locally and in parent' do
      parent = described_class.with_value(described_class.background, :user, 'alice')
      child = described_class.with_value(parent, :user, 'bob')

      expect(child[:user]).to eq('bob')
    end
  end
end
