# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '#done?' do
    context 'for background context' do
      it 'always returns false' do
        expect(described_class.background.done?).to be(false)
      end
    end

    context 'for active cancelable context' do
      let(:ctx) do
        child, = described_class.with_cancel(described_class.background)
        child
      end

      it 'returns false before cancellation' do
        expect(ctx.done?).to be(false)
      end

      it 'returns true after cancellation' do
        ctx.cancel!

        expect(ctx.done?).to be(true)
      end
    end

    context 'when parent is canceled' do
      it 'returns true for child context' do
        parent, cancel = described_class.with_cancel(described_class.background)
        child, = described_class.with_cancel(parent)

        cancel.call

        expect(parent.done?).to be(true)
        expect(child.done?).to be(true)
      end
    end

    context 'when deadline is exceeded' do
      it 'returns true' do
        ctx = described_class.new(deadline: Time.now - 1)

        expect(ctx.done?).to be(true)
      end

      it 'sets deadline_exceeded as cancel reason' do
        ctx = described_class.new(deadline: Time.now - 1)

        ctx.done?

        expect(ctx.err).to eq(:deadline_exceeded)
      end
    end
  end
end
