# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Context do
  describe '.background' do
    subject(:background) { described_class.background }

    it 'returns the same instance every time' do
      expect(described_class.background).to be(described_class.background)
    end

    it 'creates a non-cancelable context' do
      expect(background.instance_variable_get(:@cancelable)).to be(false)
    end

    it 'is never done' do
      expect(background.done?).to be(false)
    end

    it 'has no error' do
      expect(background.err).to be_nil
    end

    it 'does not create a new object on repeated calls' do
      first = described_class.background
      second = described_class.background

      expect(first.object_id).to eq(second.object_id)
    end

    it 'does nothing when cancel! is called' do
      expect { background.cancel! }.not_to raise_error
      expect(background.done?).to be(false)
      expect(background.err).to be_nil
    end
  end

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
    end
  end

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