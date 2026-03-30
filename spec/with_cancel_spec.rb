# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '.with_cancel' do
    let(:parent) { described_class.background }

    it 'returns a context and a cancel proc' do
      ctx, cancel = described_class.with_cancel(parent)

      expect(ctx).to be_a(described_class)
      expect(cancel).to respond_to(:call)
    end

    it 'creates a cancelable child context' do
      ctx, = described_class.with_cancel(parent)

      expect(ctx.instance_variable_get(:@cancelable)).to be(true)
      expect(ctx.instance_variable_get(:@parent)).to be(parent)
    end

    it 'returns an active context initially' do
      ctx, = described_class.with_cancel(parent)

      expect(ctx.done?).to be(false)
      expect(ctx.err).to be_nil
    end

    it 'cancels the context when cancel proc is called' do
      ctx, cancel = described_class.with_cancel(parent)

      cancel.call

      expect(ctx.done?).to be(true)
      expect(ctx.err).to eq(:canceled)
    end

    it 'does not register child inside non-cancelable background parent' do
      ctx, = described_class.with_cancel(parent)

      children = parent.instance_variable_get(:@children)
      expect(children).not_to include(ctx)
    end

    it 'registers child inside cancelable parent' do
      cancelable_parent, = described_class.with_cancel(described_class.background)
      child, = described_class.with_cancel(cancelable_parent)

      children = cancelable_parent.instance_variable_get(:@children)
      expect(children).to include(child)
    end
  end
end
