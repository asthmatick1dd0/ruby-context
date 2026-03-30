# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '#cancel!' do
    context 'for background context' do
      it 'does nothing' do
        background = described_class.background

        expect { background.cancel! }.not_to raise_error
        expect(background.done?).to be(false)
        expect(background.err).to be_nil
      end
    end

    context 'for cancelable context' do
      let(:ctx) do
        child, = described_class.with_cancel(described_class.background)
        child
      end

      it 'marks the context as canceled' do
        ctx.cancel!

        expect(ctx.done?).to be(true)
        expect(ctx.err).to eq(:canceled)
      end

      it 'is idempotent' do
        ctx.cancel!
        first_err = ctx.err

        ctx.cancel!
        second_err = ctx.err

        expect(first_err).to eq(:canceled)
        expect(second_err).to eq(:canceled)
      end
    end

    context 'when context has children' do
      it 'cancels all children recursively' do
        parent, = described_class.with_cancel(described_class.background)
        child, = described_class.with_cancel(parent)
        grandchild, = described_class.with_cancel(child)

        parent.cancel!

        expect(parent.done?).to be(true)
        expect(child.done?).to be(true)
        expect(grandchild.done?).to be(true)

        expect(parent.err).to eq(:canceled)
        expect(child.err).to eq(:canceled)
        expect(grandchild.err).to eq(:canceled)
      end

      it 'clears children list after cancellation' do
        parent, = described_class.with_cancel(described_class.background)
        described_class.with_cancel(parent)

        parent.cancel!

        expect(parent.instance_variable_get(:@children)).to eq([])
      end
    end
  end
end
