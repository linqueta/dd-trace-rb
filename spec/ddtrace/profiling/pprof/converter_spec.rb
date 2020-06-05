require 'spec_helper'

require 'ddtrace/profiling/pprof/builder'
require 'ddtrace/profiling/pprof/converter'

RSpec.describe Datadog::Profiling::Pprof::Converter do
  subject(:converter) { described_class.new(builder, sample_type_mappings) }
  let(:builder) { instance_double(Datadog::Profiling::Pprof::Builder) }
  let(:sample_type_mappings) { { wall_time: 0, cpu_time: 1 } }

  describe '::sample_value_types' do
    subject(:sample_value_types) { described_class.sample_value_types }
    it { expect { sample_value_types }.to raise_error(NotImplementedError) }
  end

  describe '#group_events' do
    subject(:group_events) { converter.group_events(events, &block) }
    let(:events) { [double('event'), double('event')] }

    before { allow(builder).to receive(:sample_types).and_return() }

    context 'given events and a block' do
      context 'that groups them together' do
        # Block that returns same value means events group
        let(:block) { proc { :key } }

        it do
          is_expected.to be_a_kind_of(Array)
          is_expected.to have(1).items
        end
      end

      context 'that does not group them together' do
        # Block that returns different values means events don't group
        let(:block) { proc { rand } }

        it do
          is_expected.to be_a_kind_of(Array)
          is_expected.to have(events.length).items
        end
      end
    end
  end

  describe '#add_events!' do
    subject(:add_events!) { converter.add_events!(events) }
    let(:events) { double('events') }
    it { expect { add_events! }.to raise_error(NotImplementedError) }
  end

  describe '#build_sample_values' do
    subject(:build_sample_values) { converter.build_sample_values(event) }
    let(:event) { double('event') }
    let(:sample_types) { instance_double(Datadog::Profiling::Pprof::MessageSet) }

    before do
      allow(builder).to receive(:sample_types)
        .and_return(sample_types)

      allow(sample_types).to receive(:length)
        .and_return(3)
    end

    # Builds a value Array matching number of sample types
    # and expects all values to be "no value"
    it { is_expected.to eq(Array.new(3) { Datadog::Ext::Profiling::Pprof::SAMPLE_VALUE_NO_VALUE }) }
  end
end
