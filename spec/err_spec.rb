# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '#err' do
    context 'for background context' do
      it 'returns nil' do
        expect(described_class.background.err).to be_nil
      end
    end

    context 'for active cancelable context' do
      it 'returns nil' do
        ctx, = described_class.with_cancel(described_class.background)

        expect(ctx.err).to be_nil
      end
    end

    context 'for canceled context' do
      it 'returns :canceled' do
        ctx, = described_class.with_cancel(described_class.background)

        ctx.cancel!

        expect(ctx.err).to eq(:canceled)
      end
    end

    context 'when parent is canceled' do
      it 'returns :canceled for child' do
        parent, cancel = described_class.with_cancel(described_class.background)
        child, = described_class.with_cancel(parent)

        cancel.call

        expect(child.err).to eq(:canceled)
      end
    end

    context 'when deadline is exceeded' do
      it 'returns :deadline_exceeded' do
        ctx = described_class.new(deadline: Time.now - 1)

        expect(ctx.err).to eq(:deadline_exceeded)
      end
    end
  end
end
