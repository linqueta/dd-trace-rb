require 'spec_helper'

require 'ddtrace/profiling/pprof/builder'
require 'ddtrace/profiling/pprof/converter'

RSpec.describe Datadog::Profiling::Pprof::Converter do
  subject(:converter) { described_class.new(builder) }
  let(:builder) { instance_double(Datadog::Profiling::Pprof::Builder) }

  describe '#sample_value_types' do
    subject(:sample_value_types) { converter.sample_value_types }
    it { expect { sample_value_types }.to raise_error(NotImplementedError) }
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
