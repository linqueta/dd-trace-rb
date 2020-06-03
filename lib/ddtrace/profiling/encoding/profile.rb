require 'ddtrace/profiling/flush'
require 'ddtrace/profiling/pprof/builder'
require 'ddtrace/profiling/pprof/pprof_pb'

module Datadog
  module Profiling
    module Encoding
      module Profile
        # Encodes events to pprof
        module Protobuf
          module_function

          def encode(flushes)
            return if flushes.empty?

            # Build a profile from the flushes
            builder = Pprof::Builder.new
            flushes.each { |flush| builder.add_flush!(flush) }
            profile = builder.to_profile

            Perftools::Profiles::Profile.encode(profile)
          end
        end
      end
    end
  end
end
