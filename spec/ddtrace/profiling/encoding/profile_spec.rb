require 'spec_helper'

require 'ddtrace/profiling/encoding/profile'
require 'ddtrace/profiling/events/stack'

RSpec.describe Datadog::Profiling::Encoding::Profile::Protobuf do
  describe '::encode' do
    subject(:encode) { described_class.encode(flushes) }

    let(:flushes) { [flush] }
    let(:flush) { instance_double(Datadog::Profiling::Flush) }

    let(:builder) { instance_double(Datadog::Profiling::Pprof::Builder) }
    let(:profile) { instance_double(Perftools::Profiles::Profile) }
    let(:encoded_profile) { double('encoded profile') }

    before do
      expect(Datadog::Profiling::Pprof::Builder)
        .to receive(:new)
        .and_return(builder)

      expect(builder)
        .to receive(:add_flush!)
        .with(flush)

      expect(builder)
        .to receive(:to_profile)
        .and_return(profile)

      expect(Perftools::Profiles::Profile)
        .to receive(:encode)
        .with(profile)
        .and_return(encoded_profile)
    end

    it { is_expected.to be encoded_profile }
  end
end
