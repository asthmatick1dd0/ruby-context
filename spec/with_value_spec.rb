# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '.with_value' do
    let(:background) { described_class.background }

    it 'returns a new context' do
      ctx = described_class.with_value(background, :user, 'alice')

      expect(ctx).to be_a(described_class)
      expect(ctx).not_to be(background)
    end

    it 'stores a value in the new context' do
      ctx = described_class.with_value(background, :user, 'alice')

      expect(ctx[:user]).to eq('alice')
    end

    it 'does not mutate background values' do
      ctx = described_class.with_value(background, :user, 'alice')

      expect(ctx[:user]).to eq('alice')
      expect(background[:user]).to be_nil
    end

    it 'inherits values from parent chain' do
      parent = described_class.with_value(background, :user, 'alice')
      child = described_class.with_value(parent, :request_id, '123')

      expect(child[:user]).to eq('alice')
      expect(child[:request_id]).to eq('123')
    end

    it 'prefers local value over parent value for the same key' do
      parent = described_class.with_value(background, :user, 'alice')
      child = described_class.with_value(parent, :user, 'bob')

      expect(child[:user]).to eq('bob')
    end

    it 'inherits cancelable flag from parent' do
      ctx = described_class.with_value(background, :user, 'alice')

      expect(ctx.instance_variable_get(:@cancelable)).to be(false)
    end

    it 'inherits cancelable flag from cancelable parent' do
      parent, = described_class.with_cancel(background)
      ctx = described_class.with_value(parent, :user, 'alice')

      expect(ctx.instance_variable_get(:@cancelable)).to be(true)
    end
  end
end
